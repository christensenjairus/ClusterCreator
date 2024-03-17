terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = "0.46.4"
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
          cluster_name       = cluster_name
          node_class         = node_class
          index              = i
          vm_id              = tonumber("${cluster.cluster_id}${specs.start_ip + i}")
          cores              = specs.cores
          sockets            = specs.sockets
          memory             = specs.memory
          disk_size          = specs.disk_size
          vm_ip              = "${cluster.host_networking.cluster_subnet}.${specs.start_ip + i}"
          gateway            = "${cluster.host_networking.cluster_subnet}.1"
          dns1               = cluster.host_networking.dns1
          dns2               = cluster.host_networking.dns2
          vlan_id            = cluster.host_networking.vlan_id
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
resource "unifi_network" "vlan" {
  for_each = {
    for key, value in var.clusters : key => value
    if key == terraform.workspace
  }

  name    = "${upper(each.key)}-K8S" # Name the network based on the cluster name
  purpose = "corporate" # Must be one of corporate, guest, wan, or vlan-only.

  subnet       = "${each.value.host_networking.cluster_subnet}.0/24"
  vlan_id      = each.value.host_networking.vlan_id
  dhcp_start   = "${each.value.host_networking.cluster_subnet}.10"
  dhcp_stop    = "${each.value.host_networking.cluster_subnet}.99"
  dhcp_enabled = true
  igmp_snooping = false
  multicast_dns = false
  dhcp_dns = [each.value.host_networking.dns1, each.value.host_networking.dns2]
}

resource "proxmox_virtual_environment_pool" "operations_pool" {
  depends_on = [unifi_network.vlan]
  # had to add the Pool.Audit permission to the Terraform role in Proxmox for this to work
  for_each = {
    for key, value in var.clusters : key => value
    if key == terraform.workspace
  }
  comment = "Managed by Terraform"
  pool_id = "${upper(each.key)}-K8S"
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
  name = "${each.value.cluster_name}-k8s-${each.value.node_class}-${each.value.index}"
  tags = [
    "k8s",
    each.value.cluster_name,
    each.value.node_class,
  ]
  node_name = var.proxmox_node_name
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
  disk {
    interface = "virtio0"
    size = each.value.disk_size
    datastore_id = "nvmes"
    iothread = false # not possible with virtio?
    ssd = false # not possible with virtio?
    discard = "ignore" #  not possible with virtio?
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
    datastore_id = "nvmes"
    ip_config {
      ipv4 {
        address = "${each.value.vm_ip}/24"
        gateway = "${each.value.gateway}"
      }
    }
    dns {
      domain = "lan"
      servers =  ["${each.value.dns1}", "${each.value.dns2}", "${each.value.gateway}"]
    }
  }
  network_device {
    vlan_id = each.value.vlan_id
  }
  reboot = false # Reboot is unnecessary. Already fully updated during template creation.
  migrate = true
  on_boot = true
  started = true
  pool_id = "${upper(each.value.cluster_name)}-K8S"
  lifecycle {
    ignore_changes = [
      tags,
      description,
      clone,
#      initialization[0].interface,
#      initialization[0].user_account,
#      network_device,
    ]
  }
}