terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = "0.53.1"
    }
    unifi = {
      source = "paultyng/unifi"
      version = "0.41.0"
    }
  }
}

provider "unifi" {
  username = var.unifi_username
  password = var.unifi_password
  api_url  = var.unifi_api_url
  allow_insecure = true
}

provider "proxmox" {
  endpoint = "https://${var.proxmox_host}:8006/api2/json"
  api_token = var.proxmox_api_token
  ssh {
    username = var.proxmox_username
    agent = true
  }
  insecure = true
}

locals {
  all_nodes = flatten([
    for cluster_name, cluster in var.clusters : [
      for node_class, specs in cluster.node_classes : [
        for i in range(specs.count) : {
          cluster_name       = cluster.cluster_name
          node_class         = node_class
          index              = i
          vm_id              = tonumber("${cluster.cluster_id}${specs.start_ip + i}")
          on_boot            = cluster.start_on_proxmox_boot
          cores              = specs.cores
          sockets            = specs.sockets
          memory             = specs.memory
          disks              = specs.disks
          create_vlan      = cluster.networking.create_vlan
          vlan_id          = cluster.networking.create_vlan ? cluster.networking.vlan_id: null
          vlan_name        = cluster.networking.create_vlan ? cluster.networking.vlan_name: null
          ipv4               : {
            vm_ip            = "${cluster.networking.ipv4.subnet_prefix}.${specs.start_ip + i}"
            gateway          = "${cluster.networking.ipv4.subnet_prefix}.1"
            dns1             = cluster.networking.ipv4.dns1
            dns2             = cluster.networking.ipv4.dns2
          }
          ipv6               : {
            enabled          = cluster.networking.ipv6.enabled
            dual_stack       = cluster.networking.ipv6.enabled ? cluster.networking.ipv6.dual_stack: false
            vm_ip            = cluster.networking.ipv6.enabled ? "${cluster.networking.ipv6.subnet_prefix}::${specs.start_ip + i}" : null
            gateway          = cluster.networking.ipv6.enabled ? "${cluster.networking.ipv6.subnet_prefix}::1" : null
            dns1             = cluster.networking.ipv6.enabled ? cluster.networking.ipv6.dns1: null
            dns2             = cluster.networking.ipv6.enabled ? cluster.networking.ipv6.dns2: null
          }
          dns_search_domain  = cluster.networking.dns_search_domain
        }
      ]
    ]
  ])

  cluster_config = var.clusters[terraform.workspace]

  # Now filter all_nodes to only include those from the specified cluster
  nodes = [for node in local.all_nodes : node if node.cluster_name == terraform.workspace]
}

# Local file resource to write the clusters config to a JSON file
resource "local_file" "cluster_config_json" {
  content  = jsonencode(local.cluster_config)
  filename = "ansible/tmp/${local.cluster_config.cluster_name}/cluster_config.json"
}

# create a network with a vlan for each cluster
# https://registry.terraform.io/providers/paultyng/unifi/latest/docs/resources/network
resource "unifi_network" "vlan" {
  for_each = {
    for key, value in var.clusters : key => value
    if key == terraform.workspace && value.networking.create_vlan == true
  }

  name    = each.value.networking.vlan_name
  vlan_id   = each.value.networking.vlan_id
  purpose = "corporate" # Must be one of corporate, guest, wan, or vlan-only.

  # IPv4 settings
  subnet       = "${each.value.networking.ipv4.subnet_prefix}.0/24"
  dhcp_start   = "${each.value.networking.ipv4.subnet_prefix}.10"
  dhcp_stop    = "${each.value.networking.ipv4.subnet_prefix}.99"
  dhcp_enabled = true
  igmp_snooping = false
  multicast_dns = false
  dhcp_dns = [each.value.networking.ipv4.dns1, each.value.networking.ipv4.dns2]

  # IPv6 settings
  # Use pd if ipv6 is enabled, but dual stack isn't. Use static if dual stack is enabled.
  ipv6_interface_type = each.value.networking.ipv6.enabled ? (each.value.networking.ipv6.dual_stack ? "static" : "pd") : "none"
  ipv6_static_subnet = each.value.networking.ipv6.dual_stack ? "${each.value.networking.ipv6.subnet_prefix}::1/64": null
  ipv6_pd_interface = "wan"
  ipv6_pd_start = "::2"
  ipv6_pd_stop = "::7d1"
  dhcp_v6_dns_auto = false
  dhcp_v6_enabled = true
  dhcp_v6_start = "::10"
  dhcp_v6_stop = "::99"
  dhcp_v6_dns = each.value.networking.ipv6.enabled ? [each.value.networking.ipv6.dns1, each.value.networking.ipv6.dns2]: []
  ipv6_ra_enable = true
  ipv6_ra_priority = "high"

  lifecycle {
    ignore_changes = [
      dhcp_v6_enabled # this flag doesn't seem to work as expected in the provider version used
    ]
  }
}

resource "proxmox_virtual_environment_pool" "operations_pool" {
  depends_on = [unifi_network.vlan]
  # had to add the Pool.Audit permission to the Terraform role in Proxmox for this to work
  for_each = {
    for key, value in var.clusters : key => value
    if key == terraform.workspace
  }
  comment = "Managed by Terraform"
  pool_id = "${upper(each.key)}" # pool id is the cluster name in all caps
}

# add extra output once something is done
output "filtered_nodes" {
  value = local.nodes
}

# Dynamic creation of control plane (cp) nodes based on the selected cluster configuration
# https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm
resource "proxmox_virtual_environment_vm" "node" {
  depends_on = [proxmox_virtual_environment_pool.operations_pool]
  for_each = { for node in local.nodes : "${node.cluster_name}-${node.node_class}-${node.index}" => node }

  description  = "Managed by Terraform"
  vm_id = each.value.vm_id
  name = "${each.value.cluster_name}-${each.value.node_class}-${each.value.index}"
  tags = [
    "k8s",
    each.value.cluster_name,
    each.value.node_class,
  ]
  node_name = var.proxmox_node
  clone {
    vm_id = var.template_vm_id
    full = true
    retries = 25 # Proxmox errors with timeout when creating multiple clones at once
  }
  cpu {
    cores    = each.value.cores
    sockets  = each.value.sockets
    numa = true
    type = "host"
    flags = []
  }
  memory {
    dedicated = each.value.memory
  }
  dynamic "disk" {
    for_each = each.value.disks
    content {
      interface     = "virtio${disk.value.index}"
      size          = disk.value.size
      datastore_id  = disk.value.datastore
      file_format   = "raw"
      backup        = disk.value.backup # backup the disks during vm backup
      iothread      = true
      cache         = "none" # proxmox default
      aio           = "io_uring" # proxmox default
      discard       = "ignore" # proxmox default
      ssd           = false # not possible with virtio
    }
  }
  agent {
    enabled = true
    timeout = "15m"
    trim = true
    type = "virtio"
  }
  vga {
    enabled = true
    memory = 16
    type = "serial0"
  }
  initialization {
    interface = "ide2"
    user_account {
      keys = [var.vm_ssh_key]
      password = var.vm_password
      username = var.vm_username
    }
    datastore_id = each.value.disks[0].datastore
    dynamic "ip_config" {
      for_each = [1]  # This ensures the block is always created
      content {
        dynamic "ipv4" {
          for_each = [1]  # This ensures the block is always created
          content {
            address = "${each.value.ipv4.vm_ip}/24"
            gateway = "${each.value.ipv4.gateway}"
          }
        }

        dynamic "ipv6" {
          for_each = each.value.ipv6.dual_stack ? [1] : []
          content {
            address = "${each.value.ipv6.vm_ip}/64"
            gateway = "${each.value.ipv6.gateway}"
          }
        }
      }
    }
    dns {
      domain = each.value.dns_search_domain
      servers = concat(
        [each.value.ipv4.dns1, each.value.ipv4.dns2, each.value.ipv4.gateway],
        each.value.ipv6.enabled ? [each.value.ipv6.dns1, each.value.ipv6.dns2] : []
      )
    }
  }
  network_device {
    vlan_id = each.value.vlan_id
  }
  reboot = false # reboot is performed during the ./install_k8s.sh script, but only when needed, and only on nodes not part of the cluster already.
  migrate = true
  on_boot = each.value.on_boot
  started = true
  pool_id = "${upper(each.value.cluster_name)}"
  lifecycle {
    ignore_changes = [
      tags,
      description,
      clone,
      disk, # don't remake disks, could cause data loss! Can comment this out if no production data is present
    ]
  }
}