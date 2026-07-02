#noinspection TFIncorrectVariableType
variable "clusters" {
  description = "Configuration details for each cluster."
  type = map(object({
    cluster_name             : string                                                     # Required. Name is used in kubeconfig, cluster mesh, network name, k8s_vm_template pool. Must match the cluster name key. 14 character limit.
    cluster_id               : number                                                     # Required. Acts as the vm_id and vlan prefix. This plus the vm start ip should always be over 100 because of how proxmox likes its vmids.
    region                   : optional(string, "")                                       # Optional. Region name for the cluster's topology.kubernetes.io/region label.
    kubeconfig_file_name     : string                                                     # Required. Name of the local kubeconfig file to be created. Assumed this will be in $HOME/.kube/
    start_on_proxmox_boot    : optional(bool, true)                                       # Optional. Whether or not to start the cluster's vms on proxmox boot
    max_pods_per_node        : optional(number, 512)                                      # Optional. Max pods per node. This should be a function of the quantity of IPs in you pod_cidr and number of nodes.
    image_maximum_gc_age     : optional(string, "")                                       # Optional. kubelet imageMaximumGCAge (e.g. "168h"). Reclaims images unused for longer than this. Empty leaves the kubeadm/kubelet default (age-based GC disabled).
    reboot_after_update      : optional(bool, false)                                      # Optional. Whether or not to reboot the nodes during terraform apply.
    use_pve_ha               : optional(bool, false)                                      # Optional. Whether to setup PVE High Availability for the VMs. Not currently supported on PVE 9 - https://github.com/bpg/terraform-provider-proxmox/issues/2097
    ssh                      : object({
      ssh_user               : string                                                     # Required. username for the remote server
      ssh_key_type           : optional(string, "ssh-ed25519")                            # Optional. Type of key to scan and trust for remote hosts. The key of this type gets added to local ~/.ssh/known_hosts.
    })
    networking               : object({
      search_domain          : optional(string, "lan")  
      ipv4                   : optional(object({
        pod_cidr             : optional(string, "10.42.0.0/16")                           # Optional. IPv4 CIDR for pods
        svc_cidr             : optional(string, "10.43.0.0/16")                           # Optional. IPv4 CIDR for services
        dns1                 : optional(string, "1.1.1.1")                                # Optional. Primary IPv4 DNS server
        dns2                 : optional(string, "1.0.0.1")                                # Optional. Secondary IPv4 DNS server
      }), {})
      ipv6                   : optional(object({
        pod_cidr             : optional(string, "2001:db8:cafe:0000:244::/80")            # Optional. Cidr range for pod networking internal to cluster. Should be a subsection of the ipv6 lan network. These must differ cluster to cluster if using clustermesh.
        svc_cidr             : optional(string, "2001:db8:cafe:0000:96::/112")            # Optional. Cidr range for service networking internal to cluster. Should be a subsection of the ipv6 lan network.
        dns1                 : optional(string, "2607:fa18::1")                           # Optional. Primary IPv6 DNS server
        dns2                 : optional(string, "2607:fa18::2")                           # Optional. Secondary IPv6 DNS server
      }), {})
      nics                   : optional(list(object({
        bridge               : optional(string, "vmbr0")                                  # Optional. Name of the proxmox bridge to use for VM's network interface
        vlan_id              : optional(number)                                           # Optional. VLAN ID to assign to this interface. Keep empty or null if not using vlans or the Unifi provider.
        mtu                  : optional(number, 1500)                                     # Optional. MTU for this interface
        ipv4                 : optional(object({
          subnet_prefix      : string                                                     # Required. First three octets of the IPv4 network's subnet (assuming its a /24)
          gateway            : optional(string)                                           # Optional. REQUIRED FOR FIRST NIC OR KUBEADM MAY CHOOSE THE WRONG INTERFACE. Gateway for VM hosts
          lb_cidrs           : optional(string)                                           # Optional. IPv4 CIDRs to use for MetalLB on this interface
        }))
        ipv6                 : optional(object({
          subnet_prefix      : optional(string)                                           # Optional. IPv6 subnet prefix for this interface
          gateway            : optional(string)                                           # Optional. IPv6 gateway for this interface
          lb_cidrs           : optional(string)                                           # Optional. IPv6 CIDRs to use for MetalLB on this interface
        }), {})
      })), [])
      kube_vip               : object({
        kube_vip_version     : optional(string, "0.9.2")                                  # Optional. Kube-vip version to use. Needs to be their ghcr.io docker image version
        vip_interface        : optional(string, "eth0")                                   # Optional. Interface that faces the local lan. Usually eth0 for this project.
        vip                  : string                                                     # Required. IP address of the highly available kubernetes control plane.
        vip_hostname         : string                                                     # Required. Hostname to use when querying the api server's vip load balancer (kube-vip)
        use_ipv6             : optional(bool, false)                                      # Optional. Whether or not to use an IPv6 vip. You must also set the VIP to an IPv6 address. This can be true without enabling dual_stack.
      })
    })
    node_classes             : map(object({
      count                  : number                                                     # Required. Number of VMs to create for this node class.
      pve_nodes              : optional(list(string),["pve-a","pve-b","pve-c"])           # Optional. Nodes that this class is allowed to run on. They will be cycled through and will repeat if count > length(pve_nodes).
      machine                : optional(string, "q35")                                    # Optional. Default to "q35". Use i400fx for partial gpu pass-through.
      cpu_type               : optional(string, "x86-64-v3")                              # Optional. Default to x86-64-v3. 'host' gives the best performance and is needed for full gpu pass-through, but it can't live migrate. https://www.yinfor.com/2023/06/how-i-choose-vm-cpu-type-in-proxmox-ve.html
      cores                  : optional(number, 2)                                        # Optional. Number of cores to use.
      sockets                : optional(number, 1)                                        # Optional. Number of sockets to use or emulate.
      memory                 : optional(number, 2048)                                     # Optional. Non-ballooning memory in MB.
      disks                  : list(object({                                              # Required. First disk will be used for OS. Others can be added for longhorn, ceph, etc.
        size                 : number                                                     # Required. Size of the disk in GB.
        datastore            : string                                                     # Required. The Proxmox datastore to use for this disk.
        backup               : optional(bool, true)                                       # Optional. Backup this disk when Proxmox performs a vm backup or snapshot.
        cache_mode           : optional(string, "none")                                   # Optional. See https://pve.proxmox.com/wiki/Performance_Tweaks#Small_Overview
        aio_mode             : optional(string, "io_uring")                               # Optional. io_uring, native, or threads. Native can only be used with raw block devices. Threads is legacy.
        discard              : optional(string, "ignore")                                 # Optional. Whether to enable TRIM/discard on the disk. Options are "on" or "ignore".
      }))
      start_ip               : number                                                     # Required. Last octet of the ip address for the first node of the class.
      disabled_nics          : optional(list(string), [])                                 # Optional. NICs to disable on the node in format "eth0", "eth1", etc. Useful when not all interfaces are needed for security.
      gateway_nic            : optional(string, "eth0")                                   # Optional. NIC on which to set the gateway - you should only have one of these set per node or you'll have asymmetrical routing.
      labels                 : optional(list(string), [])                                 # Optional. Kubernetes-level labels to control workload scheduling.
      taints                 : optional(list(string), [])                                 # Optional. Kubernetes-level taints to control workload scheduling.
      devices                : optional(list(object({                                     # Optional. USB or PCI(e) devices to pass-through.
        mapping              : optional(string, "")                                       # Optional. PVE datacenter-level pci or usb resource mapping name.
        type                 : optional(string, "pci")                                    # Optional. pci or usb.
        mdev                 : optional(string, "")                                       # Optional. The mediated device ID. Helpful for partial pci(e) pass-through.
        rombar               : optional(bool, true)                                       # Optional. Whether to include the rombar with the pci(e) device.
      })), [])
    }))
  }))
  default = { # create your clusters here using the above object
    "alpha" = {
      cluster_name           = "alpha"
      cluster_id             = 1
      kubeconfig_file_name   = "alpha.yml"
      start_on_proxmox_boot  = false
      ssh = {
        ssh_user = "k8s"
      }
      networking = {
        ipv4 = {
          pod_cidr = "10.42.0.0/16"
          svc_cidr = "10.43.0.0/16"
        }
        ipv6 = {}
        nics = [
          {
            bridge  = "vmbr0"
            vlan_id = null
            ipv4 = {
              subnet_prefix = "10.0.1"
              gateway       = "10.0.1.1"
              lb_cidrs      = "10.0.1.200/29,10.0.1.208/28,10.0.1.224/28,10.0.1.240/29,10.0.1.248/30,10.0.1.252/31"
            }
          }
        ]
        kube_vip = {
          vip          = "10.0.1.100"
          vip_hostname = "alpha-api-server"
        }
      }
      node_classes = {
        controlplane = {
          count    = 1
          cores    = 16
          memory   = 16384
          disks    = [
            { datastore = "local-zfs", size = 100 }
          ]
          start_ip = 110
          labels   = [
            "nodeclass=controlplane"
          ]
        }
      }
    }
    "beta" = {
      cluster_name           = "beta"
      cluster_id             = 2
      kubeconfig_file_name   = "beta.yml"
      start_on_proxmox_boot  = false
      ssh = {
        ssh_user = "k8s"
      }
      networking = {
        ipv4 = {
          pod_cidr = "10.42.0.0/16"
          svc_cidr = "10.43.0.0/16"
        }
        ipv6 = {}
        nics = [
          {
            bridge  = "vmbr0"
            vlan_id = null
            ipv4 = {
              subnet_prefix = "10.0.2"
              gateway       = "10.0.2.1"
              lb_cidrs      = "10.0.2.200/29,10.0.2.208/28,10.0.2.224/28,10.0.2.240/29,10.0.2.248/30,10.0.2.252/31"
            }
          }
        ]
        kube_vip = {
          vip          = "10.0.2.100"
          vip_hostname = "beta-api-server"
        }
      }
      node_classes = {
        controlplane = {
          count    = 1
          cores    = 4
          memory   = 4096
          disks    = [
            { datastore = "local-zfs", size = 20 }
          ]
          start_ip = 110
          labels   = [
            "nodeclass=controlplane"
          ]
        }
        general = {
          count    = 2
          cores    = 8
          memory   = 4096
          disks    = [
            { datastore = "local-zfs", size = 20 }
          ]
          start_ip = 130
          labels   = [
            "nodeclass=general"
          ]
        }
      }
    }
    "gamma" = {
      cluster_name           = "gamma"
      cluster_id             = 3
      kubeconfig_file_name   = "gamma.yml"
      start_on_proxmox_boot  = false
      ssh = {
        ssh_user = "k8s"
      }
      networking = {
        ipv4 = {
          pod_cidr = "10.42.0.0/16"
          svc_cidr = "10.43.0.0/16"
        }
        ipv6 = {}
        nics = [
          {
            bridge  = "vmbr0"
            vlan_id = null
            ipv4 = {
              subnet_prefix = "10.0.3"
              gateway       = "10.0.3.1"
              lb_cidrs      = "10.0.3.200/29,10.0.3.208/28,10.0.3.224/28,10.0.3.240/29,10.0.3.248/30,10.0.3.252/31"
            }
          }
        ]
        kube_vip = {
          vip          = "10.0.3.100"
          vip_hostname = "gamma-api-server"
        }
      }
      node_classes = {
        controlplane = {
          count    = 3
          cores    = 4
          memory   = 4096
          disks    = [
            { datastore = "local-zfs", size = 20 }
          ]
          start_ip = 110
          labels   = [
            "nodeclass=controlplane"
          ]
        }
        etcd = {
          count    = 3
          disks    = [
            { datastore = "local-zfs", size = 20 }
          ]
          start_ip = 120
        }
        general = {
          count    = 5
          cores    = 8
          memory   = 4096
          disks    = [
            { datastore = "local-zfs", size = 20 }
          ]
          start_ip = 130
          labels   = [
            "nodeclass=general"
          ]
        }
        gpu = {
          count     = 2
          pve_nodes = ["pve-b", "pve-c"] # Note: The default pve_nodes is ["pve-a","pve-b","pve-c"], this overrides it.
          cpu_type  = "host"
          disks     = [
            { datastore = "local-zfs", size = 20 }
          ]
          start_ip  = 190
          labels    = [
            "nodeclass=gpu"
          ]
          taints = [
            "gpu=true:NoSchedule"
          ]
          devices = [
            { mapping = "Sparkle_Intel_Arc_A310_ECO" } # name of the datacenter gpu mapping
          ]
        }
      }
    }
  }
}