# create a network with a vlan for each cluster
# https://registry.terraform.io/providers/paultyng/unifi/latest/docs/resources/network
resource "unifi_network" "vlan" {
  for_each = {
    for key, value in var.clusters : key => value
    # only create a vlan if it's both wanted and the VMs are assigned to it
    if key == terraform.workspace && value.networking.use_unifi == true && value.networking.assign_vlan == true
  }

  name      = upper(each.value.cluster_name)
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
  ipv6_interface_type = each.value.networking.ipv6.enabled ? "static" : "none"
  ipv6_static_subnet = each.value.networking.ipv6.enabled ? "${each.value.networking.ipv6.subnet_prefix}::1/64" : null
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
