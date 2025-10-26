#noinspection TFIncorrectVariableType
variable "networks" {
  description = "Configuration details for networks by environment."
  type = map(list(object({
    network_name        : string                                                     # Required. The name of the network in Unifi.
    vlan_id             : number                                                     # Required. The VLAN ID to assign to the network.
    search_domain       : optional(string, "lan")                                    # Optional. Search domain for DNS resolution
    ipv4                : optional(object({
      dns1              : optional(string, "1.1.1.1")                                # Optional. Primary IPv4 DNS server for this network
      dns2              : optional(string, "1.0.0.1")                                # Optional. Secondary IPv4 DNS server for this network
      subnet_prefix     : string                                                     # Required. DHCP subnet prefix for this network in UniFi
      gateway           : string                                                     # Required. DHCP gateway for this network in UniFi
    }))
    ipv6                : optional(object({
      dns1              : optional(string)                                           # Optional. Primary IPv6 DNS server for this network
      dns2              : optional(string)                                           # Optional. Secondary IPv6 DNS server for this network
      subnet_prefix     : optional(string)                                           # Optional. DHCP IPv6 subnet prefix for this network in UniFi
      gateway           : optional(string)                                           # Optional. DHCP IPv6 gateway for this network in UniFi
    }), {})
  })))
  default = { # create your networks here using the above object
    "alpha" = [
      {
        network_name       = "ALPHA"
        search_domain      = "lan"
        vlan_id            = 100
        ipv4 = {
          dns1             = "1.1.1.1"
          dns2             = "1.0.0.1"
          subnet_prefix    = "10.0.1"
          gateway          = "10.0.1.1"
        }
        ipv6 = {}
      }
    ]
    "beta" = [
      {
        network_name       = "BETA"
        search_domain      = "lan"
        vlan_id            = 200
        ipv4 = {
          dns1             = "1.1.1.1"
          dns2             = "1.0.0.1"
          subnet_prefix    = "10.0.2"
          gateway          = "10.0.2.1"
        }
        ipv6 = {}
      }
    ]
    "gamma" = [
      {
        network_name       = "GAMMA"
        search_domain      = "lan"
        vlan_id            = 300
        ipv4 = {
          dns1             = "1.1.1.1"
          dns2             = "1.0.0.1"
          subnet_prefix    = "10.0.3"
          gateway          = "10.0.3.1"
        }
        ipv6 = {}
      }
    ]
  }
}