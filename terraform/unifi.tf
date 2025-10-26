# create a network with a vlan for each cluster
# https://registry.terraform.io/providers/paultyng/unifi/latest/docs/resources/network
# resource "unifi_network" "network" {
#   for_each = {
#     for pair in flatten([
#       for network_key, networks in var.networks : [
#         for network in networks : {
#           key = "${network_key}-${network.vlan_id}"
#           network = network
#           network_key = network_key
#         }
#       ]
#     ]) : pair.key => pair
#     if pair.network_key == terraform.workspace
#   }
# 
#   vlan_id = each.value.network.vlan_id
#   name    = each.value.network.network_name
#   purpose = "corporate" # Must be one of corporate, guest, wan, or vlan-only.
#   domain_name  = each.value.network.search_domain
# 
#   # IPv4 settings - get values directly from the network object
#   subnet       = lookup(each.value.network.ipv4, "subnet_prefix", null) != null ? "${each.value.network.ipv4.subnet_prefix}.0/24" : "192.168.1.0/24"
#   dhcp_start   = lookup(each.value.network.ipv4, "subnet_prefix", null) != null ? "${each.value.network.ipv4.subnet_prefix}.10" : "192.168.1.10"
#   dhcp_stop    = lookup(each.value.network.ipv4, "subnet_prefix", null) != null ? "${each.value.network.ipv4.subnet_prefix}.99" : "192.168.1.99"
#   dhcp_enabled = true
#   igmp_snooping = false
#   multicast_dns = false
#   dhcp_dns = [
#     lookup(each.value.network.ipv4, "dns1", "1.1.1.1"),
#     lookup(each.value.network.ipv4, "dns2", "1.0.0.1")
#   ]
# 
#   # IPv6 settings - get values directly from the network object
#   ipv6_interface_type = lookup(each.value.network, "ipv6", null) != null && lookup(each.value.network.ipv6, "subnet_prefix", null) != null ? "static" : "none"
#   ipv6_static_subnet = lookup(each.value.network, "ipv6", null) != null && lookup(each.value.network.ipv6, "subnet_prefix", null) != null ? "${each.value.network.ipv6.subnet_prefix}::1/64" : null
#   dhcp_v6_dns_auto = false
#   dhcp_v6_enabled = true
#   dhcp_v6_start = "::10"
#   dhcp_v6_stop = "::99"
#   dhcp_v6_dns = lookup(each.value.network, "ipv6", null) != null && lookup(each.value.network.ipv6, "subnet_prefix", null) != null ? compact([
#     lookup(each.value.network.ipv6, "dns1", null) != null ? lookup(each.value.network.ipv6, "dns1", null) : "2606:4700:4700::1111",
#     lookup(each.value.network.ipv6, "dns2", null) != null ? lookup(each.value.network.ipv6, "dns2", null) : "2606:4700:4700::1001"
#   ]) : []
#   ipv6_ra_enable = true
#   ipv6_ra_priority = "high"
# 
#   lifecycle {
#     ignore_changes = [
#       dhcp_v6_enabled # this flag doesn't seem to work as expected in the provider version used
#     ]
#   }
# }
