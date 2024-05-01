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
    start_on_proxmox_boot            : bool   # whether or not to start the clusters vms on proxmox boot
    ssh                              : object({
      ssh_user                       : string # username for the remote server
      ssh_home                       : string # path to your home directory on the remote server
      ssh_key_type                   : string # type of key to scan and trust for remote hosts. the key of this type gets added to local ~/.ssh/known_hosts.
    })
    host_networking                  : object({
      use_vlan                       : bool   # whether or not to use vlans. If false, the vlan_id is ignored, but should still exist.
      vlan_id                        : number # vlan id for the cluster. See README on how to not use vlans
      cluster_subnet                 : string # first three octets of the network's subnet (assuming its a /24)
      dns1                           : string # primary dns server for vm hosts
      dns2                           : string # secondary dns server for vm hosts
      dns_search_domain              : string # search domain for DNS resolution
    })
    cluster_networking               : object({
      max_pods_per_node              : number # max pods per node. This should be a function of the quantity of IPs in you pod_cidr and number of nodes.
      pod_cidr                       : string # cidr range for pod networking internal to cluster. Shouldn't overlap with lan network. These must differ cluster to cluster if using clustermesh.
      svc_cidr                       : string # cidr range for service networking internal to cluster. Shouldn't overlap with lan network.
    })
    kube_vip                         : object({
      kube_vip_version               : string # kube-vip version to use. needs to be their ghcr.io docker image version
      vip_interface                  : string # interface that faces the local lan
      vip                            : string # should not be in one if your load balancer ip cidr ranges
      vip_hostname                   : string # hostname to use when querying the api server's vip load balancer (kube-vip)
    })
    cilium                           : object({
      cilium_version                 : string # release version for cilium
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
        # no node labels because etcd nodes are external to the cluster itself
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
      })
      # you can add more worker node classes here.
      # but don't change the name of the apiserver or etcd nodes unless you do a full find-replace.
    })
  }))
  default = { # create your clusters here using the above object
    "alpha" = {
      cluster_name                     = "alpha"
      cluster_id                       = 1
      kubeconfig_file_name             = "alpha.yml"
      start_on_proxmox_boot            = false
      ssh = {
        ssh_user                       = "line6"
        ssh_home                       = "/home/line6"
        ssh_key_type                   = "ssh-ed25519"
      }
      host_networking                  = {
        use_vlan                       = true
        vlan_id                        = 100
        cluster_subnet                 = "10.0.1"
        dns1                           = "10.0.1.3"
        dns2                           = "10.0.1.4"
        dns_search_domain              = "lan"
      }
      cluster_networking = {
        max_pods_per_node              = 512 # allows for 128 nodes with the /16 pod_cidr
        pod_cidr                       = "10.10.0.0/16"
        svc_cidr                       = "10.11.0.0/16"
      }
      kube_vip = {
        kube_vip_version               = "0.7.0"
        vip                            = "10.0.1.100"
        vip_hostname                   = "alpha-api-server"
        vip_interface                  = "eth0"
      }
      cilium = {
        cilium_version                 = "1.15.1"
      }
      local_path_provisioner = {
        local_path_provisioner_version = "0.0.26"
      }
      metrics_server = {
        metrics_server_version         = "0.7.0"
      }
      node_classes = {
        apiserver = {
          count      = 1
          cores      = 8
          sockets    = 2
          memory     = 16384
          disks      = [
            { index = 0, datastore = "nvmes", size = 100, backup = true }
          ]
          start_ip   = 110
          labels = {
            "nodeclass" = "apiserver"
          }
        }
        etcd = {
          count      = 0
          cores      = 1
          sockets    = 2
          memory     = 2048
          disks      = [
            { index = 0, datastore = "nvmes", size = 30, backup = true }
          ]
          start_ip   = 120
        }
        storage = {
          count      = 0
          cores      = 1
          sockets    = 2
          memory     = 2048
          disks      = [
            { index = 0, datastore = "nvmes", size = 30, backup = true }
          ]
          start_ip   = 130
          labels = {
            "nodeclass" = "storage"
          }
        }
        database = {
          count      = 0
          cores      = 2
          sockets    = 2
          memory     = 8192
          disks      = [
            { index = 0, datastore = "nvmes", size = 30, backup = true }
          ]
          start_ip   = 140
          labels = {
            "nodeclass" = "database"
          }
        }
        general = {
          count      = 0
          cores      = 4
          sockets    = 2
          memory     = 4192
          disks      = [
            { index = 0, datastore = "nvmes", size = 30, backup = true }
          ]
          start_ip   = 150
          labels = {
            "nodeclass" = "general"
          }
        }
      }
    }
    "beta" = {
      cluster_name                     = "beta"
      cluster_id                       = 2
      kubeconfig_file_name             = "beta.yml"
      start_on_proxmox_boot            = false
      ssh = {
        ssh_user                       = "line6"
        ssh_home                       = "/home/line6"
        ssh_key_type                   = "ssh-ed25519"
      }
      host_networking                  = {
        use_vlan                       = true
        vlan_id                        = 200
        cluster_subnet                 = "10.0.2"
        dns1                           = "10.0.2.3"
        dns2                           = "10.0.2.4"
        dns_search_domain              = "lan"
      }
      cluster_networking = {
        max_pods_per_node              = 512 # allows for 128 nodes with the /16 pod_cidr
        pod_cidr                       = "10.14.0.0/16"
        svc_cidr                       = "10.15.0.0/16"
      }
      kube_vip = {
        kube_vip_version               = "0.7.0"
        vip                            = "10.0.2.100"
        vip_hostname                   = "beta-api-server"
        vip_interface                  = "eth0"
      }
      cilium = {
        cilium_version                 = "1.15.1"
      }
      local_path_provisioner = {
        local_path_provisioner_version = "0.0.26"
      }
      metrics_server = {
        metrics_server_version         = "0.7.0"
      }
      node_classes = {
        apiserver = {
          count      = 1
          cores      = 2
          sockets    = 2
          memory     = 4096
          disks      = [
            { index = 0, datastore = "nvmes", size = 30, backup = true }
          ]
          start_ip   = 110
          labels = {
            "nodeclass" = "apiserver"
          }
        }
        etcd = {
          count      = 0
          cores      = 1
          sockets    = 2
          memory     = 2048
          disks      = [
            { index = 0, datastore = "nvmes", size = 30, backup = true }
          ]
          start_ip   = 120
        }
        storage = {
          count      = 1
          cores      = 1
          sockets    = 2
          memory     = 2048
          disks      = [
            { index = 0, datastore = "nvmes", size = 100, backup = true }
          ]
          start_ip   = 130
          labels = {
            "nodeclass" = "storage"
          }
        }
        database = {
          count      = 1
          cores      = 2
          sockets    = 2
          memory     = 8192
          disks      = [
            { index = 0, datastore = "nvmes", size = 50, backup = true }
          ]
          start_ip   = 140
          labels = {
            "nodeclass" = "database"
          }
        }
        general = {
          count      = 1
          cores      = 4
          sockets    = 2
          memory     = 4192
          disks      = [
            { index = 0, datastore = "nvmes", size = 30, backup = true }
          ]
          start_ip   = 150
          labels = {
            "nodeclass" = "general"
          }
        }
      }
    }
    "gamma" = {
      cluster_name                    = "gamma"
      cluster_id                      = 3
      kubeconfig_file_name            = "gamma.yml"
      start_on_proxmox_boot            = false
      ssh = {
        ssh_user                      = "line6"
        ssh_home                      = "/home/line6"
        ssh_key_type                  = "ssh-ed25519"
      }
      host_networking = {
        use_vlan                       = true
        vlan_id                        = 300
        cluster_subnet                 = "10.0.3"
        dns1                           = "10.0.3.3"
        dns2                           = "10.0.3.4"
        dns_search_domain              = "lan"
      }
      cluster_networking = {
        max_pods_per_node              = 512 # allows for 128 nodes with the /16 pod_cidr
        pod_cidr                       = "10.18.0.0/16"
        svc_cidr                       = "10.19.0.0/16"
      }
      kube_vip = {
        kube_vip_version               = "0.7.0"
        vip                            = "10.0.3.100"
        vip_hostname                   = "gamma-api-server"
        vip_interface                  = "eth0"
      }
      cilium = {
        cilium_version                 = "1.15.1"
      }
      local_path_provisioner = {
        local_path_provisioner_version = "0.0.26"
      }
      metrics_server = {
        metrics_server_version         = "0.7.0"
      }
      node_classes = {
        apiserver = {
          count   = 3
          cores   = 2
          sockets = 2
          memory  = 4096
          disks   = [
            { index = 0, datastore = "nvmes", size = 30, backup = true }
          ]
          start_ip = 110
          labels   = {
            "nodeclass" = "apiserver"
          }
        }
        etcd = {
          count    = 3
          cores    = 1
          sockets  = 2
          memory   = 2048
          disks    = [
            { index = 0, datastore = "nvmes", size = 30, backup = true }
          ]
          start_ip = 120
        }
        storage = {
          count    = 3
          cores    = 1
          sockets  = 2
          memory   = 2048
          disks    = [
            { index = 0, datastore = "nvmes", size = 30, backup = true },
            { index = 1, datastore = "nvmes", size = 100, backup = false }
          ]
          start_ip = 130
          labels   = {
            "nodeclass" = "storage"
          }
        }
        database = {
          count    = 3
          cores    = 2
          sockets  = 2
          memory   = 8192
          disks    = [
            { index = 0, datastore = "nvmes", size = 50, backup = true }
          ]
          start_ip = 140
          labels   = {
            "nodeclass" = "database"
          }
        }
        general = {
          count   = 5
          cores   = 4
          sockets = 2
          memory  = 4192
          disks   = [
            { index = 0, datastore = "nvmes", size = 30, backup = true }
          ]
          start_ip = 150
          labels   = {
            "nodeclass" = "general"
          }
        }
      }
    }
  }
}

