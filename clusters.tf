variable "cluster_name" {
  description = "The name of the Kubernetes cluster"
  type        = string
  default     = "g1"
}

variable "clusters" {
  description = "Configuration details for each cluster."
  type = map(object({
    cluster_name                   : string # name to be used in kubeconfig, cluster mesh, network name, proxmox pool
    cluster_id                     : number # used for cluster mesh and also acts as the vm_id prefix
    vlan_id                        : number # vlan id for the cluster. See README on how to not use vlans
    cluster_subnet                 : string # first three octets of the network's subnet (assuming its a /24)
    backup                         : number # currently doesn't do anything, but it's there for future use
    ssh_user                       : string # username for the remote server
    ssh_home                       : string # path to your home directory on the remote server
    ssh_key_type                   : string # type of key to trust for ssh on remote hosts
    pod_cidr                       : string # cidr range for pod networking internal to cluster. Shouldn't overlap with lan network.
    svc_cidr                       : string # cidr range for service networking internal to cluster. Shouldn't overlap with lan network.
    containerd_version             : string # release version of containerd
    runc_version                   : string # runc release version
    cni_version                    : string # release version of the cni plugins that are commonly installed alongside containerd
    etcdctl_version                : string # release version of etcdctl utility
    kube_vip_version               : string # kube-vip version to use. needs to be their ghcr.io docker image version
    cilium_version                 : string # release version for cilium
    cilium_cli_version             : string # version of the cilium cli
    cilium_cli_arch                : string # most likely amd64
    cilium_interface               : string # regex to match the interface that cilium should use. Usually these are the same as the lan interface(s.)
    hubble_version                 : string # release version for hubble
    hubble_arch                    : string # most likely amd64
    metrics_server_version         : string # release version for metrics-server
    kube_prometheus_version        : string # release version for kube-prometheus
    longhorn_chart_version         : string # helm chart version for longhorn
    longhorn_nfs_storage           : string # I use TrueNAS with another network device with the associated vlan tag.
    longhorn_domain_name           : string # domain name to use for longhorn ui ingress
    longhorn_tls_secret_name       : string # secret name for longhorn ui ingress
    grafana_domain_name            : string # domain name to use for grafana ui ingress
    grafana_tls_secret_name        : string # secret name for grafana ui ingress
    prometheus_domain_name         : string # domain name to use for prometheus ui ingress
    prometheus_tls_secret_name     : string # secret name for prometheus ui ingress
    hubble_domain_name             : string # domain name to use for hubble ui ingress
    hubble_tls_secret_name         : string # secret name for longhorn ui ingress
#   gateway_api_version            : string # version of the gateway api to use. Gateway api is not currently installed with ansible.
    cert_manager_chart_version     : string # helm chart version for cert-manager
    cert_manager_email             : string # your let's encrypt email for certificates
    cluster_issuer                 : string # should be either prod-issuer or staging-issuer - see ansible/helpers/clusterissuers.yaml.j2
    ingress_nginx_chart_version    : string # helm chart version for ingress-nginx
    groundcover_enable             : bool   # whether or not to install groundcover. Provided because the free tier only lets you have 1 cluster
    kubernetes_version_short       : string # major version of kubernetes
    kubernetes_version_medium      : string # major.minor version of kubernetes
    kubernetes_version_long        : string # major.minor.patch version of kubernetes
    vip_interface                  : string # interface that faces the local lan
    vip                            : string # should not be in one if your load balancer ip cidr ranges
    vip_hostname                   : string # hostname to use when querying the api server's vip load balancer (kube-vip)
    nginx_controller_ip            : string # must be inside one if your load balancer ip cidr ranges
    load_balancer_ip_block_start_1 : string # any of these can be blank if not in use
    load_balancer_ip_block_stop_1  : string # must have both start and stop defined or neither will be used
    load_balancer_ip_block_start_2 : string
    load_balancer_ip_block_stop_2  : string
    load_balancer_ip_block_start_3 : string
    load_balancer_ip_block_stop_3  : string
    load_balancer_ip_cidr_1        : string # any of these can be blank if not in use
    load_balancer_ip_cidr_2        : string
    load_balancer_ip_cidr_3        : string
    load_balancer_ip_cidr_4        : string
    load_balancer_ip_cidr_5        : string
    kubeconfig_file_name           : string # name of the local kubeconfig file to be created. Assumed this will be in $HOME/.kube/
    node_specs : object({
      apiserver : object({# required type, must be >= 1.
        count    : number # usually 3 for HA, should be an odd number. Can be 1. Should not pass 10 without editing start IPs
        cores    : number # raise when needed, should grow as cluster grows
        sockets  : number # on my system, the max is 2
        memory   : number # raise when needed, should grow as cluster grows
        disk_size: number # doesn't need to be much larger than the system os when using external etcd because all data is in etcd and control plane nodes are tainted to have no workloads
        start_ip : number # last octet of the ip address for the first apiserver node
      })
      etcd : object({     # required type, but can be 0.
        count    : number # use 0 for a stacked etcd architecture. Usually 3 if you want an external etcd. Should be an odd number. Should not pass 10 without editing start IPs
        cores    : number # raise when needed, should grow as cluster grows
        sockets  : number # on my system, the max is 2
        memory   : number # raise when needed, should grow as cluster grows
        disk_size: number # doesn't need to be large, but does grow as cluster size grows
        start_ip : number # last octet of the ip address for the first etcd node
      })
      backup : object({   # custom worker type, can be 0
        count    : number # Should not pass 10 without editing start IPs
        cores    : number # Does not need to be large, just for backups
        sockets  : number # on my system, the max is 2
        memory   : number # Does not need to be large, just for backups
        disk_size: number # Rule of thumb is to have same size as general nodes
        start_ip : number # last octet of the ip address for the first backup node
      })
      db : object({       # custom worker type, can be 0
        count    : number # Should not pass 10 without editing start IPs
        cores    : number # Rule of thumb is to make this half as much as the general nodes
        sockets  : number # on my system, the max is 2
        memory   : number # Rule of thumb is to make this as large as possible
        disk_size: number # Rule of thumb is to have half the size of general nodes
        start_ip : number # last octet of the ip address for the first db node
      })
      general : object({  # custom worker type, can be 0
        count    : number # Should not pass 50 without editing load balancer ip cidr and nginx ingress controller ip
        cores    : number # Rule of thumb is to make this as large as possible
        sockets  : number # on my system, the max is 2
        memory   : number # Rule of thumb is to make this half as much as the db nodes
        disk_size: number # Rule of thumb is to make this as large as possible
        start_ip : number # last octet of the ip address for the first general node.
      })
      # you can add more types here if you need to. You only need to add them to ansible/helpers/ansible-hosts.txt.j2
      # but don't change the name of the apiserver or etcd nodes unless you do a full find-replace in ansible.
    })
  }))
  default = { # create your clusters here using the above object
    "b1" = {
      cluster_name                   = "b1-k8s"
      cluster_id                     = 1
      vlan_id                        = 100
      cluster_subnet                 = "10.0.100"
      load_balancer_ip_block_start_1 = "10.0.100.200"
      load_balancer_ip_block_stop_1  = "10.0.100.254"
      load_balancer_ip_block_start_2 = ""
      load_balancer_ip_block_stop_2  = ""
      load_balancer_ip_block_start_3 = ""
      load_balancer_ip_block_stop_3  = ""
      load_balancer_ip_cidr_1        = ""
      load_balancer_ip_cidr_2        = ""
      load_balancer_ip_cidr_3        = ""
      load_balancer_ip_cidr_4        = ""
      load_balancer_ip_cidr_5        = ""
      vip                            = "10.0.100.100"
      vip_hostname                   = "b1-k8s-api-server"
      nginx_controller_ip            = "10.0.100.200"
      kubeconfig_file_name           = "b1-k8s.kubeconfig"
      ssh_user                       = "yourusername"
      ssh_home                       = "/home/yourusername"
      ssh_key_type                   = "ssh-ed25519"
      pod_cidr                       = "10.42.0.0/16"
      svc_cidr                       = "10.43.0.0/16"
      containerd_version             = "1.7.13"
      runc_version                   = "1.1.12"
      cni_version                    = "v1.4.0"
      etcdctl_version                = "3.5.12"
      kube_vip_version               = "v0.7.0"
      cilium_version                 = "v1.15.1"
      cilium_cli_version             = "v0.15.21"
      cilium_cli_arch                = "amd64"
      cilium_interface               = "^eth[0-9]+"
      hubble_version                 = "v0.13.0"
      hubble_arch                    = "amd64"
      metrics_server_version         = "v0.7.0"
      kube_prometheus_version        = "release-0.13"
      longhorn_chart_version         = "1.5.3"
      longhorn_nfs_storage           = "nfs://10.0.0.2:/mnt/HDD_POOL/k8s/longhorn/"
      longhorn_domain_name           = "longhorn-b1.yourdomain.com"
      longhorn_tls_secret_name       = "longhorn-b1-yourdomain.com-tls"
      grafana_domain_name            = "grafana-b1.yourdomain.com"
      grafana_tls_secret_name        = "grafana-b1-yourdomain.com-tls"
      prometheus_domain_name         = "prometheus-b1.yourdomain.com"
      prometheus_tls_secret_name     = "prometheus-b1-yourdomain.com-tls"
      hubble_domain_name             = "hubble-b1.yourdomain.com"
      hubble_tls_secret_name         = "hubble-b1-yourdomain.com-tls"
      cert_manager_chart_version     = "v1.14.2"
      cert_manager_email             = "youremail@gmail.com"
      cluster_issuer                 = "staging-issuer"
      ingress_nginx_chart_version    = "4.10.0"
      groundcover_enable             = false
      kubernetes_version_short       = "1.28"
      kubernetes_version_medium      = "1.28.6"
      kubernetes_version_long        = "1.28.6-1.1"
      vip_interface                  = "eth0"
      backup                         = 0
      node_specs     = {
        apiserver = {
          count    = 1
          cores    = 4
          sockets  = 2
          memory   = 8192
          disk_size = 100
          start_ip   = 110
        }
        etcd = {
          count    = 0
          cores    = 1
          sockets  = 2
          memory   = 2048
          disk_size = 30
          start_ip   = 120
        }
        backup = {
          count    = 0
          cores    = 2
          sockets  = 2
          memory   = 2048
          disk_size = 30
          start_ip  = 130
        }
        db = {
          count    = 0
          cores    = 2
          sockets  = 2
          memory   = 2048
          disk_size = 30
          start_ip  = 140
        }
        general = {
          count    = 0
          cores    = 4
          sockets  = 2
          memory   = 8192
          disk_size = 100
          start_ip  = 150
        }
      }
    }
    "g1" = {
      cluster_name                   = "g1-k8s"
      cluster_id                     = 2
      vlan_id                        = 150
      cluster_subnet                 = "10.0.150"
      load_balancer_ip_block_start_1 = "10.0.150.200"
      load_balancer_ip_block_stop_1  = "10.0.150.254"
      load_balancer_ip_block_start_2 = ""
      load_balancer_ip_block_stop_2  = ""
      load_balancer_ip_block_start_3 = ""
      load_balancer_ip_block_stop_3  = ""
      load_balancer_ip_cidr_1        = ""
      load_balancer_ip_cidr_2        = ""
      load_balancer_ip_cidr_3        = ""
      load_balancer_ip_cidr_4        = ""
      load_balancer_ip_cidr_5        = ""
      vip                            = "10.0.150.100"
      vip_hostname                   = "g1-k8s-api-server"
      nginx_controller_ip            = "10.0.150.200"
      kubeconfig_file_name           = "g1-k8s.kubeconfig"
      ssh_user                       = "yourusername"
      ssh_home                       = "/home/yourusername"
      ssh_key_type                   = "ssh-ed25519"
      pod_cidr                       = "10.42.0.0/16"
      svc_cidr                       = "10.43.0.0/16"
      containerd_version             = "1.7.13"
      runc_version                   = "1.1.12"
      cni_version                    = "v1.4.0"
      etcdctl_version                = "3.5.12"
      kube_vip_version               = "v0.7.0"
      cilium_version                 = "v1.15.1"
      cilium_cli_version             = "v0.15.21"
      cilium_cli_arch                = "amd64"
      cilium_interface               = "^eth[0-9]+"
      hubble_version                 = "v0.13.0"
      hubble_arch                    = "amd64"
      metrics_server_version         = "v0.7.0"
      kube_prometheus_version        = "release-0.13"
      longhorn_chart_version         = "1.5.3"
      longhorn_nfs_storage           = "nfs://10.0.150.2:/mnt/HDD_POOL/k8s/longhorn/"
      longhorn_domain_name           = "longhorn-g1.yourdomain.com"
      longhorn_tls_secret_name       = "longhorn-g1-yourdomain.com-tls"
      grafana_domain_name            = "grafana-g1.yourdomain.com"
      grafana_tls_secret_name        = "grafana-g1-yourdomain.com-tls"
      prometheus_domain_name         = "prometheus-g1.yourdomain.com"
      prometheus_tls_secret_name     = "prometheus-g1-yourdomain.com-tls"
      hubble_domain_name             = "hubble-g1.yourdomain.com"
      hubble_tls_secret_name         = "hubble-g1-yourdomain.com-tls"
      cert_manager_chart_version     = "v1.14.2"
      cert_manager_email             = "youremail@gmail.com"
      cluster_issuer                 = "staging-issuer"
      ingress_nginx_chart_version    = "4.10.0"
      groundcover_enable             = false
      kubernetes_version_short       = "1.28"
      kubernetes_version_medium      = "1.28.6"
      kubernetes_version_long        = "1.28.6-1.1"
      vip_interface                  = "eth0"
      backup                         = 0
      node_specs     = {
        apiserver = {
          count    = 3
          cores    = 2
          sockets  = 2
          memory   = 4096
          disk_size = 30
          start_ip  = 110
        }
        etcd = {
          count    = 3
          cores    = 1
          sockets  = 2
          memory   = 2048
          disk_size = 30
          start_ip  = 120
        }
        backup = {
          count    = 0
          cores    = 2
          sockets  = 2
          memory   = 2048
          disk_size = 100
          start_ip  = 130
        }
        db = {
          count    = 0
          cores    = 2
          sockets  = 2
          memory   = 8192
          disk_size = 50
          start_ip  = 140
        }
        general = {
          count    = 3
          cores    = 4
          sockets  = 2
          memory   = 8192
          disk_size = 100
          start_ip  = 150
        }
      }
    }
    "z1" = {
      cluster_name                   = "z1-k8s"
      cluster_id                     = 3
      vlan_id                        = 200
      cluster_subnet                 = "10.0.200"
      load_balancer_ip_block_start_1 = "10.0.200.200"
      load_balancer_ip_block_stop_1  = "10.0.200.254"
      load_balancer_ip_block_start_2 = ""
      load_balancer_ip_block_stop_2  = ""
      load_balancer_ip_block_start_3 = ""
      load_balancer_ip_block_stop_3  = ""
      load_balancer_ip_cidr_1        = ""
      load_balancer_ip_cidr_2        = ""
      load_balancer_ip_cidr_3        = ""
      load_balancer_ip_cidr_4        = ""
      load_balancer_ip_cidr_5        = ""
      vip                            = "10.0.200.100"
      vip_hostname                   = "z1-k8s-api-server"
      nginx_controller_ip            = "10.0.200.200"
      kubeconfig_file_name           = "z1-k8s.kubeconfig"
      ssh_user                       = "yourusername"
      ssh_home                       = "/home/yourusername"
      ssh_key_type                   = "ssh-ed25519"
      pod_cidr                       = "10.42.0.0/16"
      svc_cidr                       = "10.43.0.0/16"
      containerd_version             = "1.7.13"
      runc_version                   = "1.1.12"
      cni_version                    = "v1.4.0"
      etcdctl_version                = "3.5.12"
      kube_vip_version               = "v0.7.0"
      cilium_version                 = "v1.15.1"
      cilium_cli_version             = "v0.15.21"
      cilium_cli_arch                = "amd64"
      cilium_interface               = "^eth[0-9]+"
      hubble_version                 = "v0.13.0"
      hubble_arch                    = "amd64"
      metrics_server_version         = "v0.7.0"
      kube_prometheus_version        = "release-0.13"
      longhorn_chart_version         = "1.5.3"
      longhorn_nfs_storage           = "nfs://10.0.210.2:/mnt/HDD_POOL/k8s/longhorn/"
      longhorn_domain_name           = "longhorn-z1.yourdomain.com"
      longhorn_tls_secret_name       = "longhorn-z1-yourdomain.com-tls"
      grafana_domain_name            = "grafana-z1.yourdomain.com"
      grafana_tls_secret_name        = "grafana-z1-yourdomain.com-tls"
      prometheus_domain_name         = "prometheus-z1.yourdomain.com"
      prometheus_tls_secret_name     = "prometheus-z1-yourdomain.com-tls"
      hubble_domain_name             = "hubble-z1.yourdomain.com"
      hubble_tls_secret_name         = "hubble-z1-yourdomain.com-tls"
      cert_manager_chart_version     = "v1.14.2"
      cert_manager_email             = "youremail@gmail.com"
      cluster_issuer                 = "staging-issuer"
      ingress_nginx_chart_version    = "4.10.0"
      groundcover_enable             = false
      kubernetes_version_short       = "1.28"
      kubernetes_version_medium      = "1.28.6"
      kubernetes_version_long        = "1.28.6-1.1"
      vip_interface                  = "eth0"
      backup                         = 1
      node_specs     = {
        apiserver = {
          count    = 5
          cores    = 2
          sockets  = 2
          memory   = 4096
          disk_size= 30
          start_ip = 110
        }
        etcd = {
          count    = 5
          cores    = 1
          sockets  = 2
          memory   = 2048
          disk_size= 30
          start_ip = 120
        }
        backup = {
          count    = 2
          cores    = 2
          sockets  = 2
          memory   = 2048
          disk_size= 30
          start_ip = 130
        }
        db = {
          count    = 3
          cores    = 4
          sockets  = 2
          memory   = 4096
          disk_size= 30
          start_ip = 140
        }
        general = {
          count    = 5
          cores    = 8
          sockets  = 2
          memory   = 4096
          disk_size= 30
          start_ip = 150
        }
      }
    }
  }
}

