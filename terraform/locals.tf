locals {
  all_nodes = flatten([
    for cluster_name, cluster in var.clusters : [
      for node_class, specs in cluster.node_classes : [
        for i in range(specs.count) : {
          cluster_name        = cluster.cluster_name
          cluster_id          = cluster.cluster_id
          region              = cluster.region
          node_class          = node_class
          index               = i
          vm_id               = tonumber("${cluster.cluster_id}${specs.start_ip + i}")
          on_boot             = cluster.start_on_proxmox_boot
          reboot_after_update = cluster.reboot_after_update
          use_pve_ha          = cluster.use_pve_ha && specs.cpu_type != "host"
          cores               = specs.cores
          sockets             = specs.sockets
          memory              = specs.memory
          disks               = specs.disks
          devices             = specs.devices
          pve_nodes           = specs.pve_nodes
          machine             = specs.machine
          cpu_type            = specs.cpu_type
          disabled_nics       = lookup(specs, "disabled_nics", [])
          gateway_nic         = specs.gateway_nic
          
          # Pass through networking configuration
          networking         = cluster.networking
          
          # Calculate IP addresses for each node
          node_ips = {
            # For each NIC, add the node-specific IP addresses based on subnet_prefix
            nics = [
              for nic in lookup(cluster.networking, "nics", []) : merge(nic, {
                node_ipv4_address = lookup(nic, "ipv4", null) != null ? "${nic.ipv4.subnet_prefix}.${specs.start_ip + i}" : null
                node_ipv6_address = lookup(nic, "ipv6", null) != null && lookup(nic.ipv6, "subnet_prefix", null) != null ? "${nic.ipv6.subnet_prefix}::${specs.start_ip + i}" : null
              })
            ]
          }
        }
      ]
    ]
  ])

  cluster_config = var.clusters[terraform.workspace]

  # Extract potential gateway IPs from NICs to use as DNS servers
  gateway_ips = distinct(flatten([
    for nic in lookup(local.cluster_config.networking, "nics", []) :
      lookup(nic, "ipv4", null) != null && lookup(nic.ipv4, "gateway", null) != null && nic.ipv4.gateway != "" ?
        [nic.ipv4.gateway] : []
  ]))

  # Default DNS servers for VMs - use gateways as DNS if available, otherwise fallback to Cloudflare DNS
  default_dns_servers = length(local.gateway_ips) > 0 ? local.gateway_ips : ["1.1.1.1", "1.0.0.1"]

  # Now filter all_nodes to only include those from the specified cluster
  nodes = [for node in local.all_nodes : node if node.cluster_name == terraform.workspace]
}

# Local file resource to write the clusters config to a JSON file
resource "local_file" "cluster_config_json" {
  content  = jsonencode(local.cluster_config)
  filename = "../ansible/tmp/${local.cluster_config.cluster_name}/cluster_config.json"
}
