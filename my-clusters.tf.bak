variable "cluster_name" {
  description = "The short name of the Kubernetes cluster"
  type        = string
  default     = "epsilon"
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
      dns_search_domain              : string # search domain for DNS resolution
      create_vlan                    : bool   # whether or not to create an IPv4 vlan.
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
      })
      storage       : object({      # custom worker type, can be 0
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
        start_ip    : number        # last octet of the ip address for the first backup node
        labels      : map(string)   # labels to apply to the nodes
        taints      : map(string)   # taints to apply to the nodes
      })            
      database      : object({      # custom worker type, can be 0
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
        start_ip    : number        # last octet of the ip address for the first db node
        labels      : map(string)   # labels to apply to the nodes
        taints      : map(string)   # taints to apply to the nodes
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
      })
      # you can add more worker node classes here. You must also add a section per node class to the ansible/helpers/ansible_hosts.txt.j2 template file
      # but don't change the name of the apiserver or etcd nodes unless you do a full find-replace.
    })
  }))
  default = { # create your clusters here using the above object
    "delta" = {
      cluster_name                     = "delta"
      cluster_id                       = 4
      kubeconfig_file_name             = "delta.yml"
      start_on_proxmox_boot            = false
      max_pods_per_node                = 512
      ssh = {
        ssh_user                       = "line6"
        ssh_home                       = "/home/line6"
        ssh_key_type                   = "ssh-ed25519"
      }
      networking                       = {
        dns_search_domain              = "lan"
        vlan_name                      = "DELTA"
        vlan_id                        = 400
        create_vlan                    = true
        ipv4                           = {
          subnet_prefix                = "10.0.4"
          pod_cidr                     = "10.10.0.0/16"
          svc_cidr                     = "10.11.0.0/16"
          dns1                         = "10.0.4.3"
          dns2                         = "10.0.4.4"
        }
        ipv6                           = {
          enabled                      = true
          dual_stack                   = true
          subnet_prefix                = "2607:fa18:47fd:400"
          pod_cidr                     = "2607:fa18:47fd:400:244::/80"
          svc_cidr                     = "2607:fa18:47fd:400:96::/112"
          dns1                         = "2607:fa18::1"
          dns2                         = "2607:fa18::2"
        }
        kube_vip = {
          kube_vip_version             = "0.8.1"
          vip                          = "10.0.4.100" #"2607:fa18:47fd:2::100"
          vip_hostname                 = "delta-api-server"
          vip_interface                = "eth0"
          use_ipv6                     = false
        }
        cilium = {
          cilium_version               = "1.15.6"
        }
      }
      local_path_provisioner = {
        local_path_provisioner_version = "0.0.28"
      }
      metrics_server = {
        metrics_server_version         = "0.7.1"
      }
      node_classes = {
        apiserver = {
          count      = 1
          cores      = 12  # need a ton for testing large apps like clustered Splunk
          sockets    = 2
          memory     = 24576 # need a ton for testing large apps like clustered Splunk
          disks      = [
            { index = 0, datastore = "nvmes", size = 100, backup = true }
          ]
          start_ip   = 110
          labels = {
            "nodeclass" = "apiserver"
          }
          taints = {}
        }
        etcd = {
          count      = 0
          cores      = 1
          sockets    = 2
          memory     = 2048
          disks      = [
            { index = 0, datastore = "nvmes", size = 20, backup = true }
          ]
          start_ip   = 120
        }
        storage = {
          count      = 0
          cores      = 1
          sockets    = 2
          memory     = 2048
          disks      = [
            { index = 0, datastore = "nvmes", size = 20, backup = true }
          ]
          start_ip   = 130
          labels = {
            "nodeclass" = "storage"
          }
          taints = {}
        }
        database = {
          count      = 0
          cores      = 2
          sockets    = 2
          memory     = 8192
          disks      = [
            { index = 0, datastore = "nvmes", size = 20, backup = true }
          ]
          start_ip   = 140
          labels = {
            "nodeclass" = "database"
          }
          taints = {}
        }
        general = {
          count      = 0
          cores      = 4
          sockets    = 2
          memory     = 4192
          disks      = [
            { index = 0, datastore = "nvmes", size = 20, backup = true }
          ]
          start_ip   = 150
          labels = {
            "nodeclass" = "general"
          }
          taints = {}
        }
      }
    }
    "epsilon" = {
      cluster_name                     = "epsilon"
      cluster_id                       = 5
      kubeconfig_file_name             = "epsilon.yml"
      start_on_proxmox_boot            = false
      max_pods_per_node                = 512
      ssh = {
        ssh_user                       = "line6"
        ssh_home                       = "/home/line6"
        ssh_key_type                   = "ssh-ed25519"
      }
      networking                       = {
        dns_search_domain              = "lan"
        create_vlan                    = true
        vlan_name                      = "EPSILON"
        vlan_id                        = 500
        ipv4                           = {
          subnet_prefix                = "10.0.5"
          pod_cidr                     = "10.14.0.0/16"
          svc_cidr                     = "10.15.0.0/16"
          dns1                         = "10.0.5.3"
          dns2                         = "10.0.5.4"
        }
        ipv6                           = {
          enabled                      = true
          dual_stack                   = true
          subnet_prefix                = "2607:fa18:47fd:500"
          pod_cidr                     = "2607:fa18:47fd:500:244::/80"
          svc_cidr                     = "2607:fa18:47fd:500:96::/112"
          dns1                         = "2607:fa18::1"
          dns2                         = "2607:fa18::2"
        }
        kube_vip = {
          kube_vip_version             = "0.8.1"
          vip                          = "10.0.5.100"
          vip_hostname                 = "epsilon-api-server"
          vip_interface                = "eth0"
          use_ipv6                     = false
        }
        cilium = {
          cilium_version                 = "1.15.6"
        }
      }
      local_path_provisioner = {
        local_path_provisioner_version = "0.0.28"
      }
      metrics_server = {
        metrics_server_version         = "0.7.1"
      }
      node_classes = {
        apiserver = {
          count      = 1
          cores      = 2
          sockets    = 2
          memory     = 4096
          disks      = [
            { index = 0, datastore = "nvmes", size = 20, backup = true }
          ]
          start_ip   = 110
          labels = {
            "nodeclass" = "apiserver"
          }
          taints = {}
        }
        etcd = {
          count      = 0
          cores      = 1
          sockets    = 2
          memory     = 2048
          disks      = [
            { index = 0, datastore = "nvmes", size = 20, backup = true }
          ]
          start_ip   = 120
        }
        storage = {
          count      = 1
          cores      = 4
          sockets    = 2
          memory     = 8192
          disks      = [
            { index = 0, datastore = "nvmes", size = 20, backup = true },
            { index = 1, datastore = "nvmes", size = 100, backup = false }
          ]
          start_ip   = 130
          labels = {
            "nodeclass" = "storage"
          }
          taints = {}
        }
        database = {
          count      = 1
          cores      = 4
          sockets    = 2
          memory     = 8192
          disks      = [
            { index = 0, datastore = "nvmes", size = 50, backup = true }, # big enough to hold vitess databases
            { index = 1, datastore = "nvmes", size = 100, backup = false }
          ]
          start_ip   = 140
          labels = {
            "nodeclass" = "database"
          }
          taints = {}
        }
        general = {
          count      = 1
          cores      = 10
          sockets    = 2
          memory     = 18432
          disks      = [
            { index = 0, datastore = "nvmes", size = 20, backup = true },
            { index = 1, datastore = "nvmes", size = 100, backup = false }
          ]
          start_ip   = 150
          labels = {
            "nodeclass" = "general"
          }
          taints = {}
        }
      }
    }
    "zeta" = {
      cluster_name                     = "zeta"
      cluster_id                       = 6
      kubeconfig_file_name             = "zeta.yml"
      start_on_proxmox_boot            = false #true
      max_pods_per_node                = 512
      ssh                              = {
        ssh_user                       = "line6"
        ssh_home                       = "/home/line6"
        ssh_key_type                   = "ssh-ed25519"
      }
      networking                       = {
        dns_search_domain              = "lan"
        create_vlan                    = true
        vlan_name                      = "ZETA"
        vlan_id                        = 600
        ipv4                           = {
          subnet_prefix                = "10.0.6"
          pod_cidr                     = "10.18.0.0/16"
          svc_cidr                     = "10.19.0.0/16"
          dns1                         = "10.0.6.3"
          dns2                         = "10.0.6.4"
        }
        ipv6                           = {
          enabled                      = true
          dual_stack                   = true
          subnet_prefix                = "2607:fa18:47fd:600"
          pod_cidr                     = "2607:fa18:47fd:600:244::/80"
          svc_cidr                     = "2607:fa18:47fd:600:96::/112"
          dns1                         = "2607:fa18::1"
          dns2                         = "2607:fa18::2"
        }
        kube_vip = {
          kube_vip_version             = "0.8.1"
          vip                          = "10.0.6.100"
          vip_hostname                 = "zeta-api-server"
          vip_interface                = "eth0"
          use_ipv6                     = false
        }
        cilium = {
          cilium_version               = "1.15.6"
        }
      }
      local_path_provisioner = {
        local_path_provisioner_version = "0.0.28"
      }
      metrics_server = {
        metrics_server_version         = "0.7.1"
      }
      node_classes = {
        apiserver = {
          count    = 3
          cores    = 2
          sockets  = 2
          memory   = 8192
          disks    = [
            { index = 0, datastore = "nvmes", size = 20, backup = true }
          ]
          start_ip = 110
          labels   = {
            "nodeclass" = "apiserver"
          }
          taints   = {}
        }
        etcd = {
          count    = 3
          cores    = 1
          sockets  = 2
          memory   = 3072
          disks    = [
            { index = 0, datastore = "nvmes", size = 30, backup = true } # an extra 10 for extra space for etcd backups. 24+7 of them at 250MB each is 8GB.
          ]
          start_ip = 120
        }
        storage = {
          count    = 4 # need three minimum for my replication level, an extra to maintain HEALTH_OK when I take one down for maintenance
          cores    = 4
          sockets  = 2
          memory   = 12288
          disks    = [
            { index = 0, datastore = "nvmes", size = 70, backup = true }, # an extra 50 for rook mon folder /rook/rook-ceph
            { index = 1, datastore = "nvmes", size = 100, backup = false }, # 400GB could be full and still leave space for os disks on Proxmox
            { index = 2, datastore = "nvmes", size = 100, backup = false }, # separating them out to help with rook performance
            { index = 3, datastore = "nvmes", size = 100, backup = false },
            { index = 4, datastore = "nvmes", size = 100, backup = false }
          ]
          start_ip = 130
          labels   = {
            "nodeclass" = "storage"
          }
          taints   = {}
        }
        database = {
          count    = 3 # should be three or more. Redis and postgres clusters are assigned to these nodes. They have three nodes w/ spread constraints.
          cores    = 4
          sockets  = 2
          memory   = 12288
          disks    = [
            { index = 0, datastore = "nvmes", size = 50, backup = true } # an extra 30 for vitess databases as local-path volumes.
          ]
          start_ip = 140
          labels   = {
            "nodeclass" = "database"
          }
          taints   = {}
        }
        general = {
          count    = 3 # should be three or more. Various apps are spread across these nodes to maintain spread. Like splunk search heads and indexers.
          cores    = 16
          sockets  = 2
          memory   = 32768
          disks    = [
            { index = 0, datastore = "nvmes", size = 70, backup = true } # an extra 50 for emptyDir volumes for holding a ton of local copies of images. I got disk pressure taints with 30GB and low kubelet space warnings with 50GB.
          ]
          start_ip = 150
          labels   = {
            "nodeclass" = "general"
          }
          taints   = {}
        }
      }
    }
    "omega" = {
      cluster_name                     = "omega"
      cluster_id                       = 7
      kubeconfig_file_name             = "omega.yml"
      start_on_proxmox_boot            = true
      max_pods_per_node                = 512
      ssh                              = {
        ssh_user                       = "line6"
        ssh_home                       = "/home/line6"
        ssh_key_type                   = "ssh-ed25519"
      }
      networking                       = {
        dns_search_domain              = "lan"
        create_vlan                    = true
        vlan_name                      = "OMEGA"
        vlan_id                        = 700
        ipv4                           = {
          subnet_prefix                = "10.0.7"
          pod_cidr                     = "10.22.0.0/16"
          svc_cidr                     = "10.23.0.0/16"
          dns1                         = "10.0.7.3"
          dns2                         = "10.0.7.4"
        }
        ipv6                           = {
          enabled                      = true
          dual_stack                   = true
          subnet_prefix                = "2607:fa18:47fd:700"
          pod_cidr                     = "2607:fa18:47fd:700:244::/80"
          svc_cidr                     = "2607:fa18:47fd:700:96::/112"
          dns1                         = "2607:fa18::1"
          dns2                         = "2607:fa18::2"
        }
        kube_vip = {
          kube_vip_version             = "0.8.1"
          vip                          = "10.0.7.100"
          vip_hostname                 = "omega-api-server"
          vip_interface                = "eth0"
          use_ipv6                     = false
        }
        cilium = {
          cilium_version               = "1.15.6"
        }
      }
      local_path_provisioner = {
        local_path_provisioner_version = "0.0.28"
      }
      metrics_server = {
        metrics_server_version         = "0.7.1"
      }
      node_classes = {
        apiserver = {
          count    = 3
          cores    = 2
          sockets  = 2
          memory   = 8192
          disks    = [
            { index = 0, datastore = "nvmes", size = 20, backup = true }
          ]
          start_ip = 110
          labels   = {
            "nodeclass" = "apiserver"
          }
          taints   = {}
        }
        etcd = {
          count    = 3
          cores    = 1
          sockets  = 2
          memory   = 3072
          disks    = [
            { index = 0, datastore = "nvmes", size = 30, backup = true } # an extra 10 for extra space for etcd backups. 24+7 of them at 250MB each is 8GB.
          ]
          start_ip = 120
        }
        storage = {
          count    = 4 # need three minimum for my replication level, an extra to maintain HEALTH_OK when I take one down for maintenance
          cores    = 4
          sockets  = 2
          memory   = 12288
          disks    = [
            { index = 0, datastore = "nvmes", size = 20, backup = true }, # an extra 50 for rook mon folder /rook/rook-ceph
            { index = 1, datastore = "nvmes", size = 100, backup = false }, # 400GB could be full and still leave space for os disks on Proxmox
            { index = 2, datastore = "nvmes", size = 100, backup = false }, # separating them out to help with rook performance
            { index = 3, datastore = "nvmes", size = 100, backup = false },
            { index = 4, datastore = "nvmes", size = 100, backup = false }
          ]
          start_ip = 130
          labels   = {
            "nodeclass" = "storage"
          }
          taints   = {
            "storage-node" = "NoSchedule"
          }
        }
        database = {
          count    = 3 # should be three or more. Redis and postgres clusters are assigned to these nodes. They have three nodes w/ spread constraints.
          cores    = 4
          sockets  = 2
          memory   = 12288
          disks    = [
            { index = 0, datastore = "nvmes", size = 50, backup = true } # an extra 30 for vitess databases as local-path volumes.
          ]
          start_ip = 140
          labels   = {
            "nodeclass" = "database"
          }
          taints   = {}
        }
        general = {
          count    = 4 # should be three or more. Various apps are spread across these nodes to maintain spread. Like splunk search heads and indexers.
          cores    = 16
          sockets  = 2
          memory   = 24576
          disks    = [
            { index = 0, datastore = "nvmes", size = 120, backup = true } # an extra 50 for emptyDir volumes for holding a ton of local copies of images. I got disk pressure taints with 30GB and low kubelet space warnings with 50GB. An extra 50 for rook mon folder /rook/rook-ceph
          ]
          start_ip = 150
          labels   = {
            "nodeclass" = "general"
          }
          taints   = {}
        }
      }
    }
  }
}

