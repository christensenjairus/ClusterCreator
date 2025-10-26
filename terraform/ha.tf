resource "proxmox_virtual_environment_hagroup" "ha_group" {
  for_each = {
    for node in local.nodes : "${node.cluster_name}-${node.node_class}-${node.index}" => node
    if node.use_pve_ha
  }

  group   = "vm-${each.value.vm_id}"
  comment = "Managed by Terraform"

  nodes = each.value.cpu_type == "host" ? {
    # For host CPU type, only include the specific node this VM is assigned to
    for node in [each.value.pve_nodes[each.value.index % length(each.value.pve_nodes)]] :
    node => 2
  } : {
    # For non-host CPU types, use all nodes with priority as before
    for node in each.value.pve_nodes :
    node => node == each.value.pve_nodes[each.value.index % length(each.value.pve_nodes)] ? 2 : 1
  }

  restricted  = true
  no_failback = false
}

resource "proxmox_virtual_environment_haresource" "ha_resource" {
  for_each = {
    for node in local.nodes : "${node.cluster_name}-${node.node_class}-${node.index}" => node
    if node.use_pve_ha
  }

  depends_on = [
    proxmox_virtual_environment_hagroup.ha_group,
    proxmox_virtual_environment_vm.node # wait for all vms to be made
  ]

  resource_id = "vm:${each.value.vm_id}"
  state       = "started"
  group       = proxmox_virtual_environment_hagroup.ha_group[each.key].group
  comment     = "Managed by Terraform"

  max_relocate = each.value.cpu_type == "host" ? 0 : length(proxmox_virtual_environment_hagroup.ha_group[each.key].nodes) - 1
  max_restart  = length(proxmox_virtual_environment_hagroup.ha_group[each.key].nodes) - 1
}