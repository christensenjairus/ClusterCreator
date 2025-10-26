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
  # Dynamically set node_name based on cycling through the pve_nodes array
  node_name = each.value.pve_nodes[each.value.index % length(each.value.pve_nodes)]
  clone {
    vm_id     = local.template_vm_id
    full      = true
    retries   = 25     # Proxmox errors with timeout when creating multiple clones at once
    node_name = local.proxmox_node
  }
  machine = each.value.machine == "i440fx" ? "pc" : "q35"
  cpu {
    cores    = each.value.cores
    sockets  = each.value.sockets
    numa = true
    # need host cpu type for pci passthrough. But host VMs can't be live-migrated, so use standard x86-64-v2-AES for the other VMs
    type = each.value.cpu_type
    flags = []
  }
  memory {
    dedicated = each.value.memory
  }
  dynamic "disk" {
    for_each = each.value.disks
    content {
      interface     = "virtio${index(each.value.disks, disk.value)}"
      size          = disk.value.size
      datastore_id  = disk.value.datastore
      file_format   = "raw"
      backup        = disk.value.backup     # backup the disks during vm backup
      # https://pve.proxmox.com/wiki/Performance_Tweaks
      iothread      = true
      cache         = disk.value.cache_mode # none is proxmox default. Writeback provides a little extra speed with more risk during power failure.
      aio           = disk.value.aio_mode   # io_uring is proxmox default. Native can only be used with raw block devices.
      discard       = disk.value.discard
      ssd           = false                 # not possible with virtio
    }
  }
  dynamic "hostpci" {
    for_each = [for device in each.value.devices : device if device.type == "pci" || !contains(keys(device), "type")]
    content {
      device  = "hostpci${index(each.value.devices, hostpci.value)}"  # Use sequential index from devices array
      mapping = hostpci.value.mapping
      pcie    = true
      mdev    = try(hostpci.value.mdev, null) != "" ? hostpci.value.mdev : null
      rombar  = try(hostpci.value.rombar, true)
    }
  }
  dynamic "usb" {
    for_each = [for device in each.value.devices : device if device.type == "usb"]
    content {
      host    = "hostusb${index(each.value.devices, usb.value)}"
      mapping = usb.value.mapping
      usb3    = true
    }
  }
  agent {
    enabled = true
    timeout = "15m"
    trim = true
    type = "virtio"
  }
  vga {
    memory = 16
    type = "serial0"
  }
  initialization {
    interface = "ide2"
    user_account {
      keys = var.vm_ssh_key
      password = var.vm_password
      username = var.vm_username
    }
    datastore_id = each.value.disks[0].datastore

    # Create IP configurations for each NIC (excluding disabled NICs)
    dynamic "ip_config" {
      for_each = { for k, v in each.value.node_ips.nics : k => v if !contains(lookup(each.value, "disabled_nics", []), "eth${k}") }
      content {
        # IPv4 configuration
        dynamic "ipv4" {
          for_each = ip_config.value.node_ipv4_address != null ? [1] : []
          content {
            address = "${ip_config.value.node_ipv4_address}/24"
            gateway = lookup(each.value, "gateway_nic", null) != null && "eth${ip_config.key}" == lookup(each.value, "gateway_nic", null) ? lookup(ip_config.value.ipv4, "gateway", null) : null
          }
        }
        
        # IPv6 configuration
        dynamic "ipv6" {
          for_each = ip_config.value.node_ipv6_address != null ? [1] : []
          content {
            address = "${ip_config.value.node_ipv6_address}/64"
            gateway = lookup(each.value, "gateway_nic", null) != null && "eth${ip_config.key}" == lookup(each.value, "gateway_nic", null) ? lookup(ip_config.value.ipv6, "gateway", null) : null
          }
        }
      }
    }
    
    # DNS configuration
    dns {
      # Use the search_domain from the dns block
      domain = lookup(each.value.networking, "dns", null) != null ? lookup(each.value.networking, "search_domain", "lan") : "lan"
      
      # Use DNS servers from the dns block if available
      servers = lookup(each.value.networking, "dns", null) != null ? concat(lookup(each.value.networking, "ipv4", null) != null ? [lookup(each.value.networking.ipv4, "dns1", "1.1.1.1"), lookup(each.value.networking.ipv4, "dns2", "1.0.0.1")] : ["1.1.1.1", "1.0.0.1"], lookup(each.value.networking, "ipv6", null) != null ? compact([lookup(each.value.networking.ipv6, "dns1", null), lookup(each.value.networking.ipv6, "dns2", null)]) : []) : ["1.1.1.1", "1.0.0.1"]
    }
  }
  
  # Create network devices for each NIC (excluding disabled NICs)
  dynamic "network_device" {
    for_each = { for k, v in each.value.node_ips.nics : k => v if !contains(lookup(each.value, "disabled_nics", []), "eth${k}") }
    content {
      model = "virtio"
      bridge = network_device.value.bridge
      vlan_id = lookup(network_device.value, "vlan_id", null)
      mtu = lookup(network_device.value, "mtu", 1500)
      firewall = true
    }
  }
  
  reboot              = false # reboot is performed during the ./install_k8s.sh script, but only when needed, and only on nodes not part of the cluster already.
  stop_on_destroy     = true  # stop the node when the terraform resource is destroyed. We don't care about data loss because it's being destroyed.
  migrate             = true
  on_boot             = each.value.on_boot
  reboot_after_update = each.value.reboot_after_update
  started             = true
  pool_id             = upper(each.value.cluster_name)
  lifecycle {
    ignore_changes = [
      tags,
      description,
      clone,
      machine,
      operating_system,
      hostpci, # pci devices using database level mapping re-set the mapping once it's booted

      # Changes to this block may recreate the VM!
      initialization
    ]
  }
}
