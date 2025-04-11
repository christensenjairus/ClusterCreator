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
      discard       = "ignore"              # proxmox default
      ssd           = false                 # not possible with virtio
    }
  }
  dynamic "hostpci" {
    for_each = { for device in each.value.devices : device.mapping => device if device.type == "pci" }
    content {
      device  = "hostpci${hostpci.key}"  # `key` from for_each is used for the index
      mapping = hostpci.value.mapping
      pcie    = true
      mdev    = try(hostpci.value.mdev, null) != "" ? hostpci.value.mdev : null
      rombar  = hostpci.value.rombar
    }
  }
  dynamic "usb" {
    for_each = { for device in each.value.devices : device.mapping => device if device.type == "usb" }
    content {
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
    dynamic "ip_config" {
      for_each = [1]  # This ensures the block is always created
      content {
        dynamic "ipv4" {
          for_each = [1]  # This ensures the block is always created
          content {
            address = "${each.value.ipv4.vm_ip}/24"
            gateway = each.value.ipv4.gateway
          }
        }
        dynamic "ipv6" {
          for_each = each.value.ipv6.enabled ? [1] : []
          content {
            address = "${each.value.ipv6.vm_ip}/64"
            gateway = each.value.ipv6.gateway
          }
        }
      }
    }
    dns {
      domain = each.value.dns_search_domain
      servers = concat(
        [each.value.ipv4.dns1, each.value.ipv4.dns2],
          each.value.ipv6.enabled ? [each.value.ipv6.dns1, each.value.ipv6.dns2] : []
      )
    }
  }
  network_device {
    vlan_id = each.value.vlan_id
    bridge  = each.value.bridge
    firewall = true # we'll toggle the firewall at the node level so it can be toggled w/ terraform without restarting the node
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

      # Changes to this block will recreate the VM!
      initialization,
      
      # You can comment "disk" out if no production data is present or if you're expanding the disk size and carefully read the Tofu plan.
      # This is here to protect against disks being accidentally recreated, which would cause data loss.
      disk,
    ]
  }
}
