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
          devices            = specs.devices
          pve_nodes          = specs.pve_nodes
          machine            = specs.machine
          cpu_type           = specs.cpu_type
          bridge             = cluster.networking.bridge
          create_vlan        = cluster.networking.create_vlan
          vlan_id            = cluster.networking.assign_vlan ? cluster.networking.vlan_id: null
          vlan_name          = cluster.networking.create_vlan ? cluster.networking.vlan_name: null
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

  management_ranges_ipv4_list = split(",", local.cluster_config.networking.management_ranges_ipv4)
  management_ranges_ipv6_list = split(",", local.cluster_config.networking.management_ranges_ipv6)

  # Now filter all_nodes to only include those from the specified cluster
  nodes = [for node in local.all_nodes : node if node.cluster_name == terraform.workspace]
}

# Local file resource to write the clusters config to a JSON file
resource "local_file" "cluster_config_json" {
  content  = jsonencode(local.cluster_config)
  filename = "ansible/tmp/${local.cluster_config.cluster_name}/cluster_config.json"
}