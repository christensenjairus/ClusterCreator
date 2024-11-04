variable "cluster_name" {
  description = "The short name of the Kubernetes cluster"
  type        = string
  default     = "beta"
}

variable "clusters" {
  description = "Configuration details for each cluster."
  type = map(object({
    cluster_name                     : string # name to be used in kubeconfig, cluster mesh, network name, k8s_vm_template pool. Must match the cluster name key.
    cluster_id                       : number # acts as the vm_id prefix. Also used for cluster mesh. This plus the vm start ip should always be over 100 because of how proxmox likes its vmids. But you can use 0 if the vm start id fits these requirements.
    kubeconfig_file_name             : string # name of the local kubeconfig file to be created. Assumed this will be in $HOME/.kube/
    start_on_proxmox_boot            : bool   # whether or not to start the cluster's vms on proxmox boot
    max_pods_per_node                : number # max pods per node. This should be a function of the quantity of IPs in you pod_cidr and number of nodes.
    ssh                              : object({
      ssh_user                       : string # username for the remote server
      ssh_home                       : string # path to your home directory on the remote server
      ssh_key_type                   : string # type of key to scan and trust for remote hosts. the key of this type gets added to local ~/.ssh/known_hosts.
    })
    networking                       : object({
      bridge                         : string # name of the proxmox bridge to use for VM's network interface
      dns_search_domain              : string # search domain for DNS resolution
      assign_vlan                    : bool   # whether or not to assign a vlan to the network interfaces of the VMs.
      create_vlan                    : bool   # whether or not to create an IPv4 vlan in Unifi.
      vlan_name                      : string # name of the IPv4 vlan for the cluster. Must always be set, even if create_vlan is false.
      vlan_id                        : number # vlan id for the cluster. Must always be set, even if create_vlan is false.
      ipv4                           : object({
        subnet_prefix                : string # first three octets of the IPv4 network's subnet (assuming its a /24)
        pod_cidr                     : string # cidr range for pod networking internal to cluster. Shouldn't overlap with ipv4 lan network. These must differ cluster to cluster if using clustermesh.
        svc_cidr                     : string # cidr range for service networking internal to cluster. Shouldn't overlap with ipv4 lan network.
        dns1                         : string # primary dns server for vm hosts
        dns2                         : string # secondary dns server for vm hosts
      })
      ipv6                           : object({
        enabled                      : bool   # whether or not to enable IPv6 networking for the VMs and network in the cluster. Does not enable dual stack services, but does allow ipv6 between hosts and the internet. Disabled sets the ipv6_vlan_mode to "none".
        dual_stack                   : bool   # whether or not to enable dual stack networking for the cluster. EXPECT COMPLICATIONS IF CHANGED AFTER INITIAL SETUP.
        subnet_prefix                : string # first four hex sections of the IPv6 network's subnet (assuming its a /64). Used for a static network configuration.
        pod_cidr                     : string # cidr range for pod networking internal to cluster. Should be a subsection of the ipv6 lan network. These must differ cluster to cluster if using clustermesh.
        svc_cidr                     : string # cidr range for service networking internal to cluster. Should be a subsection of the ipv6 lan network.
        dns1                         : string # primary dns server for vm hosts
        dns2                         : string # secondary dns server for vm hosts
      })
      kube_vip                       : object({
        kube_vip_version             : string # kube-vip version to use. needs to be their ghcr.io docker image version
        vip_interface                : string # interface that faces the local lan. Usually eth0 for this project.
        vip                          : string # should be IPv4 and not be in one if your load balancer ip cidr ranges
        vip_hostname                 : string # hostname to use when querying the api server's vip load balancer (kube-vip)
        use_ipv6                     : bool   # whether or not to use an IPv6 vip. You must also set the VIP to an IPv6 address. This can be true without enabling dual_stack.
      })
      cilium                         : object({
        cilium_version               : string # release version for cilium
      })
    })
    local_path_provisioner           : object({
      local_path_provisioner_version : string # version for Rancher's local path provisioner
    })
    metrics_server                   : object({
      metrics_server_version         : string # release version for metrics-server
    })
    node_classes    : object({
      apiserver     : object({      # required type, must be >= 1.
        count       : number        # usually 3 for HA, should be an odd number. Can be 1. Should not pass 10 without editing start IPs
        cores       : number        # raise when needed, should grow as cluster grows
        sockets     : number        # on my system, the max is 2
        memory      : number        # raise when needed, should grow as cluster grows
        disks       : list(object({ # First disk will be used for OS. Other disks are added for other needs. Must have at least one disk here even if count is 0.
          index     : number        # index of the disk. 0 is the first disk. 1 is the second disk. etc.
          size      : number        # size of disk in GB.
          datastore : string        # name of the proxmox datastore to use for this disk
          backup    : bool          # boolean to determine if this disk will be backed up when Proxmox performs a vm backup.
        }))
        start_ip    : number        # last octet of the ip address for the first apiserver node
        labels      : map(string)   # labels to apply to the nodes
        taints      : map(string)   # taints to apply to the nodes
        devices     : list(object({ # PCI or USB Mappings to pass into the VM.
          index     : number        # index of the device. 0 is the first device. 1 is the second device. etc. Max of 15 pci devices
          mapping   : string        # datacenter-level pci or usb resource mapping name. You must make the mapping beforehand. https://pve.proxmox.com/wiki/QEMU/KVM_Virtual_Machines#resource_mapping
          type      : string        # pci or usb
        }))
      })
      etcd          : object({      # required type, but can be 0.
        count       : number        # use 0 for a stacked etcd architecture. Usually 3 if you want an external etcd. Should be an odd number. Should not pass 10 without editing start IPs
        cores       : number        # raise when needed, should grow as cluster grows
        sockets     : number        # on my system, the max is 2
        memory      : number        # raise when needed, should grow as cluster grows
        disks       : list(object({ # First disk will be used for OS. Other disks are added for other needs. Must have at least one disk here even if count is 0.
          index     : number        # index of the disk. 0 is the first disk. 1 is the second disk. etc.
          size      : number        # size of disk in GB.
          datastore : string        # name of the proxmox datastore to use for this disk
          backup    : bool          # boolean to determine if this disk will be backed up when Proxmox performs a vm backup.
        }))
        start_ip    : number        # last octet of the ip address for the first etcd node
        # no node labels or taints because etcd nodes are external to the cluster itself
        devices     : list(object({ # PCI Mappings to pass into the VM. You must migrate VMs to different nodes if count > 1. If not, only one VM will get the device.
          index     : number        # index of the device. 0 is the first device. 1 is the second device. etc. Max of 15 pci devices
          mapping   : string        # datacenter-level pci or usb resource mapping name. You must make the mapping beforehand. https://pve.proxmox.com/wiki/QEMU/KVM_Virtual_Machines#resource_mapping
          type      : string        # pci or usb
        }))
      })
      general       : object({      # custom worker type, can be 0
        count       : number        # Should not pass 50 without editing load balancer ip cidr and nginx ingress controller ip
        cores       : number
        sockets     : number        # on my system, the max is 2
        memory      : number
        disks       : list(object({ # First disk will be used for OS. Other disks are added for other needs. Must have at least one disk here even if count is 0.
          index     : number        # index of the disk. 0 is the first disk. 1 is the second disk. etc.
          size      : number        # size of disk in GB.
          datastore : string        # name of the proxmox datastore to use for this disk
          backup    : bool          # boolean to determine if this disk will be backed up when Proxmox performs a vm backup.
        }))
        start_ip    : number        # last octet of the ip address for the first general node.
        labels      : map(string)   # labels to apply to the nodes
        taints      : map(string)   # taints to apply to the nodes
        devices     : list(object({ # PCI Mappings to pass into the VM. You must migrate VMs to different nodes if count > 1. If not, only one VM will get the device.
          index     : number        # index of the device. 0 is the first device. 1 is the second device. etc. Max of 15 pci devices
          mapping   : string        # datacenter-level pci or usb resource mapping name. You must make the mapping beforehand. https://pve.proxmox.com/wiki/QEMU/KVM_Virtual_Machines#resource_mapping
          type      : string        # pci or usb
        }))
      })
      gpu      : object({      # custom worker type, can be 0
        count       : number        # Should not pass 10 without editing start IPs
        cores       : number
        sockets     : number        # on my system, the max is 2
        memory      : number
        disks       : list(object({ # First disk will be used for OS. Other disks are added for other needs. Must have at least one disk here even if count is 0.
          index     : number        # index of the disk. 0 is the first disk. 1 is the second disk. etc.
          size      : number        # size of disk in GB.
          datastore : string        # name of the proxmox datastore to use for this disk
          backup    : bool          # boolean to determine if this disk will be backed up when Proxmox performs a vm backup.
        }))
        start_ip    : number        # last octet of the ip address for the first gpu node
        labels      : map(string)   # labels to apply to the nodes
        taints      : map(string)   # taints to apply to the nodes
        devices     : list(object({ # PCI Mappings to pass into the VM. You must migrate VMs to different nodes if count > 1. If not, only one VM will get the device.
          index     : number        # index of the device. 0 is the first device. 1 is the second device. etc. Max of 15 pci devices
          mapping   : string        # datacenter-level pci or usb resource mapping name. You must make the mapping beforehand. https://pve.proxmox.com/wiki/QEMU/KVM_Virtual_Machines#resource_mapping
          type      : string        # pci or usb
        }))
      })
      # Add more worker node classes here
    })
  }))
  default = { # create your clusters here using the above object
    "alpha" = {
      cluster_name                     = "alpha"
      cluster_id                       = 1
      kubeconfig_file_name             = "alpha.yml"
      start_on_proxmox_boot            = false
      max_pods_per_node                = 512
      ssh = {
        ssh_user                       = "line6"
        ssh_home                       = "/home/line6"
        ssh_key_type                   = "ssh-ed25519"
      }
      networking                       = {
        bridge                         = "vmbr0"
        dns_search_domain              = "lan"
        vlan_name                      = "ALPHA"
        vlan_id                        = 100
        assign_vlan                    = true
        create_vlan                    = true
        ipv4                           = {
          subnet_prefix                = "10.0.1"
          pod_cidr                     = "10.8.0.0/16"
          svc_cidr                     = "10.9.0.0/16"
          dns1                         = "10.0.1.3"
          dns2                         = "10.0.1.4"
        }
        ipv6                           = {
          enabled                      = false
          dual_stack                   = false
          subnet_prefix                = "[replace-me]:100"
          pod_cidr                     = "[replace-me]:100:244::/80"
          svc_cidr                     = "[replace-me]:100:96::/112"
          dns1                         = "2607:fa18::1" # cloudflare ipv6 dns
          dns2                         = "2607:fa18::2"
        }
        kube_vip = {
          kube_vip_version             = "0.8.3"
          vip                          = "10.0.1.100"
          vip_hostname                 = "alpha-api-server"
          vip_interface                = "eth0"
          use_ipv6                     = false
        }
        cilium = {
          cilium_version               = "1.16.1"
        }
      }
      local_path_provisioner = {
        local_path_provisioner_version = "0.0.29"
      }
      metrics_server = {
        metrics_server_version         = "0.7.2"
      }
      node_classes = {
        apiserver = {
          count      = 1
          cores      = 8
          sockets    = 2
          memory     = 16384
          disks      = [
            { index = 0, datastore = "pve-block", size = 100, backup = true }
          ]
          start_ip   = 110
          labels = {
            "nodeclass" = "apiserver"
          }
          taints  = {}
          devices = []
        }
        etcd = {
          count      = 0
          cores      = 1
          sockets    = 2
          memory     = 2048
          disks      = [
            { index = 0, datastore = "pve-block", size = 20, backup = true }
          ]
          start_ip   = 120
          devices    = []
        }
        general = {
          count      = 0
          cores      = 4
          sockets    = 2
          memory     = 4096
          disks      = [
            { index = 0, datastore = "pve-block", size = 20, backup = true }
          ]
          start_ip   = 130
          labels = {
            "nodeclass" = "general"
          }
          taints  = {}
          devices = []
        }
        gpu = {
          count      = 0
          cores      = 1
          sockets    = 2
          memory     = 2048
          disks      = [
            { index = 0, datastore = "pve-block", size = 20, backup = true }
          ]
          start_ip   = 190
          labels = {
            "nodeclass" = "gpu"
          }
          taints  = {
            "gpu" = "true:NoSchedule"
          }
          devices = [
            { index = 0, mapping = "my-gpu-mapping", type = "pci" }
          ]
        }
      }
    }
    "beta" = {
      cluster_name                     = "beta"
      cluster_id                       = 2
      kubeconfig_file_name             = "beta.yml"
      start_on_proxmox_boot            = false
      max_pods_per_node                = 512
      ssh = {
        ssh_user                       = "line6"
        ssh_home                       = "/home/line6"
        ssh_key_type                   = "ssh-ed25519"
      }
      networking                       = {
        bridge                         = "vmbr0"
        dns_search_domain              = "lan"
        assign_vlan                    = true
        create_vlan                    = true
        vlan_name                      = "BETA"
        vlan_id                        = 200
        ipv4                           = {
          subnet_prefix                = "10.0.2"
          pod_cidr                     = "10.12.0.0/16"
          svc_cidr                     = "10.13.0.0/16"
          dns1                         = "10.0.2.3"
          dns2                         = "10.0.2.4"
        }
        ipv6                           = {
          enabled                      = false
          dual_stack                   = false
          subnet_prefix                = "[replace-me]:200"
          pod_cidr                     = "[replace-me]:200:244::/80"
          svc_cidr                     = "[replace-me]:200:96::/112"
          dns1                         = "2607:fa18::1" # cloudflare ipv6 dns
          dns2                         = "2607:fa18::2"
        }
        kube_vip = {
          kube_vip_version             = "0.8.3"
          vip                          = "10.0.2.100"
          vip_hostname                 = "beta-api-server"
          vip_interface                = "eth0"
          use_ipv6                     = false
        }
        cilium = {
          cilium_version                 = "1.16.1"
        }
      }
      local_path_provisioner = {
        local_path_provisioner_version = "0.0.29"
      }
      metrics_server = {
        metrics_server_version         = "0.7.2"
      }
      node_classes = {
        apiserver = {
          count      = 1
          cores      = 2
          sockets    = 2
          memory     = 4096
          disks      = [
            { index = 0, datastore = "pve-block", size = 20, backup = true }
          ]
          start_ip   = 110
          labels = {
            "nodeclass" = "apiserver"
          }
          taints  = {}
          devices = []
        }
        etcd = {
          count      = 0
          cores      = 1
          sockets    = 2
          memory     = 2048
          disks      = [
            { index = 0, datastore = "pve-block", size = 20, backup = true }
          ]
          start_ip   = 120
          devices    = []
        }
        general = {
          count      = 2
          cores      = 4
          sockets    = 2
          memory     = 4096
          disks      = [
            { index = 0, datastore = "pve-block", size = 20, backup = true }
          ]
          start_ip   = 130
          labels = {
            "nodeclass" = "general"
          }
          taints  = {}
          devices = []
        }
        gpu = {
          count      = 0
          cores      = 1
          sockets    = 2
          memory     = 2048
          disks      = [
            { index = 0, datastore = "pve-block", size = 20, backup = true }
          ]
          start_ip   = 190
          labels = {
            "nodeclass" = "gpu"
          }
          taints  = {
            "gpu" = "true:NoSchedule"
          }
          devices = [
            { index = 0, mapping = "my-gpu-mapping", type = "pci" }
          ]
        }
      }
    }
    "gamma" = {
      cluster_name                     = "gamma"
      cluster_id                       = 3
      kubeconfig_file_name             = "gamma.yml"
      start_on_proxmox_boot            = false
      max_pods_per_node                = 512
      ssh                              = {
        ssh_user                       = "line6"
        ssh_home                       = "/home/line6"
        ssh_key_type                   = "ssh-ed25519"
      }
      networking                       = {
        bridge                         = "vmbr0"
        dns_search_domain              = "lan"
        assign_vlan                    = true
        create_vlan                    = true
        vlan_name                      = "GAMMA"
        vlan_id                        = 600
        ipv4                           = {
          subnet_prefix                = "10.0.3"
          pod_cidr                     = "10.16.0.0/16"
          svc_cidr                     = "10.17.0.0/16"
          dns1                         = "10.0.3.3"
          dns2                         = "10.0.3.4"
        }
        ipv6                           = {
          enabled                      = false
          dual_stack                   = false
          subnet_prefix                = "[replace-me]:300"
          pod_cidr                     = "[replace-me]:300:244::/80"
          svc_cidr                     = "[replace-me]:300:96::/112"
          dns1                         = "2607:fa18::1" # cloudflare ipv6 dns
          dns2                         = "2607:fa18::2"
        }
        kube_vip = {
          kube_vip_version             = "0.8.3"
          vip                          = "10.0.3.100"
          vip_hostname                 = "gamma-api-server"
          vip_interface                = "eth0"
          use_ipv6                     = false
        }
        cilium = {
          cilium_version               = "1.16.1"
        }
      }
      local_path_provisioner = {
        local_path_provisioner_version = "0.0.29"
      }
      metrics_server = {
        metrics_server_version         = "0.7.2"
      }
      node_classes = {
        apiserver = {
          count    = 3
          cores    = 2
          sockets  = 2
          memory   = 4096
          disks    = [
            { index = 0, datastore = "pve-block", size = 20, backup = true }
          ]
          start_ip = 110
          labels   = {
            "nodeclass" = "apiserver"
          }
          taints  = {}
          devices = []
        }
        etcd = {
          count    = 3
          cores    = 1
          sockets  = 2
          memory   = 2048
          disks    = [
            { index = 0, datastore = "pve-block", size = 20, backup = true }
          ]
          start_ip = 120
          devices  = []
        }
        general = {
          count    = 5
          cores    = 4
          sockets  = 2
          memory   = 4096
          disks    = [
            { index = 0, datastore = "pve-block", size = 20, backup = true }
          ]
          start_ip = 130
          labels   = {
            "nodeclass" = "general"
          }
          taints  = {}
          devices = []
        }
        gpu = {
          count      = 2
          cores      = 1
          sockets    = 2
          memory     = 2048
          disks      = [
            { index = 0, datastore = "pve-block", size = 20, backup = true }
          ]
          start_ip   = 190
          labels = {
            "nodeclass" = "gpu"
          }
          taints  = {
            "gpu" = "true:NoSchedule"
          }
          devices = [
            { index = 0, mapping = "my-gpu-mapping", type = "pci" }
          ]
        }
      }
    }
  }
}

