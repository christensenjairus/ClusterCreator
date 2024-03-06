variable "cluster_name" {
  description = "The name of the Kubernetes cluster"
  type        = string
  default     = "g1"
}

variable "clusters" {
  description = "Configuration details for each cluster."
  type = map(object({
    cluster_name              : string
    cluster_id                : number
    vlan_id                   : number
    cluster_subnet            : string # first three octets of the network's subnet (assuming its a /24)
    backup                    : number # currently doesn't do anything, but it's there for future use
    ssh_user                  : string # username for the remote server
    ssh_home                  : string # path to your home directory on the remote server
    ssh_key_type              : string # type of key to trust for ssh on remote hosts
    pod_cidr                  : string
    svc_cidr                  : string
    containerd_version        : string
    runc_version              : string
    cni_version               : string
    etcdctl_version           : string
    kube_vip_version          : string
    cilium_version            : string
    cilium_cli_version        : string
    cilium_cli_arch           : string
    cilium_interface          : string
    hubble_version            : string
    hubble_arch               : string
    metrics_server_version    : string
    kube_prometheus_version   : string
    longhorn_chart_version    : string
    longhorn_nfs_storage      : string # I use TrueNAS with another network device with the associated vlan tag.
    longhorn_domain_name      : string
    longhorn_tls_secret_name  : string
    grafana_domain_name       : string
    grafana_tls_secret_name   : string
    prometheus_domain_name    : string
    prometheus_tls_secret_name: string
    hubble_domain_name        : string
    hubble_tls_secret_name    : string
#   gateway_api_version       : string
    cert_manager_chart_version: string
    cert_manager_email        : string
    cluster_issuer            : string # should be either prod-issuer or staging-issuer - see ansible/helpers/clusterissuers.yaml.j2
    ingress_nginx_chart_version: string
    groundcover_enable        : bool
    kubernetes_version_short  : string
    kubernetes_version_medium : string
    kubernetes_version_long   : string
    vip_interface             : string
    vip                       : string # should not be in one if your load balancer ip cidr ranges
    vip_hostname              : string
    nginx_controller_ip       : string # must be inside one if your load balancer ip cidr ranges
    load_balancer_ip_block_start_1 : string
    load_balancer_ip_block_stop_1  : string
    load_balancer_ip_block_start_2 : string
    load_balancer_ip_block_stop_2  : string
    load_balancer_ip_block_start_3 : string
    load_balancer_ip_block_stop_3  : string
    load_balancer_ip_cidr_1   : string # any of these can be blank if not in use
    load_balancer_ip_cidr_2   : string
    load_balancer_ip_cidr_3   : string
    load_balancer_ip_cidr_4   : string
    load_balancer_ip_cidr_5   : string
    kubeconfig_file_name      : string
    node_specs     : object({
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
  default = {
    "b1" = {
      cluster_name              = "b1-k8s"
      cluster_id                = 1
      vlan_id                   = 100
      cluster_subnet            = "10.0.100"
      load_balancer_ip_block_start_1 = "10.0.100.200"
      load_balancer_ip_block_stop_1  = "10.0.100.254"
      load_balancer_ip_block_start_2 = ""
      load_balancer_ip_block_stop_2  = ""
      load_balancer_ip_block_start_3 = ""
      load_balancer_ip_block_stop_3  = ""
      load_balancer_ip_cidr_1   = ""
      load_balancer_ip_cidr_2   = ""
      load_balancer_ip_cidr_3   = ""
      load_balancer_ip_cidr_4   = ""
      load_balancer_ip_cidr_5   = ""
      vip                       = "10.0.100.100"
      vip_hostname              = "b1-k8s-api-server"
      nginx_controller_ip       = "10.0.100.200"
      kubeconfig_file_name      = "b1-k8s.kubeconfig"
      ssh_user                  = "your_username"
      ssh_home                  = "/home/your_username"
      ssh_key_type              = "ssh-ed25519"
      pod_cidr                  = "10.42.0.0/16"
      svc_cidr                  = "10.43.0.0/16"
      containerd_version        = "1.7.13"
      runc_version              = "1.1.12"
      cni_version               = "v1.4.0"
      etcdctl_version           = "3.5.12"
      kube_vip_version          = "v0.7.0"
      cilium_version            = "v1.15.1"
      cilium_cli_version        = "v0.15.21"
      cilium_cli_arch           = "amd64"
      cilium_interface          = "^eth[0-9]+"
      hubble_version            = "v0.13.0"
      hubble_arch               = "amd64"
      metrics_server_version    = "v0.7.0"
      kube_prometheus_version   = "release-0.13"
      longhorn_chart_version    = "1.5.3"
      longhorn_nfs_storage      = "nfs://10.0.100.2:/mnt/HDD_POOL/k8s/longhorn/"
      longhorn_domain_name      = "longhorn-b1.example.com"
      longhorn_tls_secret_name  = "longhorn-b1-example.com-tls"
      grafana_domain_name       = "grafana-b1.example.com"
      grafana_tls_secret_name   = "grafana-b1-example.com-tls"
      prometheus_domain_name    = "prometheus-b1.example.com"
      prometheus_tls_secret_name= "prometheus-b1-example.com-tls"
      hubble_domain_name        = "hubble-b1.example.com"
      hubble_tls_secret_name    = "hubble-b1-example.com-tls"
#     gateway_api_version       = "v1.0.0"
      cert_manager_chart_version= "v1.14.2"
      cert_manager_email        = "your_email@email.com"
      cluster_issuer            = "staging-issuer"
      ingress_nginx_chart_version= "4.10.0"
      groundcover_enable        = false
      kubernetes_version_short  = "1.28"
      kubernetes_version_medium = "1.28.6"
      kubernetes_version_long   = "1.28.6-1.1"
      vip_interface             = "eth0"
      backup                    = 0
      node_specs     = {
        apiserver = {
          count    = 1 # no HA, just one apiserver
          cores    = 4
          sockets  = 2
          memory   = 8192
          disk_size = 100
          start_ip   = 110
        }
        etcd = {
          count    = 0 # stacked etcd on control plane (apiserver) node
          cores    = 1
          sockets  = 2
          memory   = 2048
          disk_size = 30
          start_ip   = 120
        }
        backup = {
          count    = 0 # no backup servers
          cores    = 2
          sockets  = 2
          memory   = 2048
          disk_size = 30
          start_ip  = 130
        }
        db = {
          count    = 0 # no db servers
          cores    = 2
          sockets  = 2
          memory   = 2048
          disk_size = 30
          start_ip  = 140
        }
        general = {
          count    = 0 # no general servers
          cores    = 4
          sockets  = 2
          memory   = 8192
          disk_size = 100
          start_ip  = 150
        }
      }
    }
    "g1" = {
      cluster_name              = "g1-k8s"
      cluster_id                = 2
      vlan_id                   = 150
      cluster_subnet            = "10.0.150"
      load_balancer_ip_block_start_1 = "10.0.150.200"
      load_balancer_ip_block_stop_1  = "10.0.150.254"
      load_balancer_ip_block_start_2 = ""
      load_balancer_ip_block_stop_2  = ""
      load_balancer_ip_block_start_3 = ""
      load_balancer_ip_block_stop_3  = ""
      load_balancer_ip_cidr_1   = ""
      load_balancer_ip_cidr_2   = ""
      load_balancer_ip_cidr_3   = ""
      load_balancer_ip_cidr_4   = ""
      load_balancer_ip_cidr_5   = ""
      vip                       = "10.0.150.100"
      vip_hostname              = "g1-k8s-api-server"
      nginx_controller_ip       = "10.0.150.200"
      kubeconfig_file_name      = "g1-k8s.kubeconfig"
      ssh_user                  = "your_username"
      ssh_home                  = "/home/your_username"
      ssh_key_type              = "ssh-ed25519"
      pod_cidr                  = "10.42.0.0/16"
      svc_cidr                  = "10.43.0.0/16"
      containerd_version        = "1.7.13"
      runc_version              = "1.1.12"
      cni_version               = "v1.4.0"
      etcdctl_version           = "3.5.12"
      kube_vip_version          = "v0.7.0"
      cilium_version            = "v1.15.1"
      cilium_cli_version        = "v0.15.21"
      cilium_cli_arch           = "amd64"
      cilium_interface          = "^eth[0-9]+"
      hubble_version            = "v0.13.0"
      hubble_arch               = "amd64"
      metrics_server_version    = "v0.7.0"
      kube_prometheus_version   = "release-0.13"
      longhorn_chart_version    = "1.5.3"
      longhorn_nfs_storage      = "nfs://10.0.150.2:/mnt/HDD_POOL/k8s/longhorn/"
      longhorn_domain_name      = "longhorn-g1.example.com"
      longhorn_tls_secret_name  = "longhorn-g1-example.com-tls"
      grafana_domain_name       = "grafana-g1.example.com"
      grafana_tls_secret_name   = "grafana-g1-example.com-tls"
      prometheus_domain_name    = "prometheus-g1.example.com"
      prometheus_tls_secret_name= "prometheus-g1-example.com-tls"
      hubble_domain_name        = "hubble-g1.example.com"
      hubble_tls_secret_name    = "hubble-g1-example.com-tls"
#     gateway_api_version       = "v1.0.0"
      cert_manager_chart_version= "v1.14.2"
      cert_manager_email        = "your_email@email.com"
      cluster_issuer            = "staging-issuer"
      ingress_nginx_chart_version= "4.10.0"
      groundcover_enable        = false
      kubernetes_version_short  = "1.28"
      kubernetes_version_medium = "1.28.6"
      kubernetes_version_long   = "1.28.6-1.1"
      vip_interface             = "eth0"
      backup         = 0
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
          count    = 3 # external etcd on these nodes, removing that responsibility from control plane nodes
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
          count    = 3 # adding worker nodes
          cores    = 4
          sockets  = 2
          memory   = 8192
          disk_size = 100
          start_ip  = 150
        }
      }
    }
    "z1" = {
      cluster_name              = "z1-k8s"
      cluster_id                = 3
      vlan_id                   = 200
      cluster_subnet            = "10.0.200"
      load_balancer_ip_block_start_1 = "10.0.200.200"
      load_balancer_ip_block_stop_1  = "10.0.200.254"
      load_balancer_ip_block_start_2 = ""
      load_balancer_ip_block_stop_2  = ""
      load_balancer_ip_block_start_3 = ""
      load_balancer_ip_block_stop_3  = ""
      load_balancer_ip_cidr_1   = ""
      load_balancer_ip_cidr_2   = ""
      load_balancer_ip_cidr_3   = ""
      load_balancer_ip_cidr_4   = ""
      load_balancer_ip_cidr_5   = ""
      vip                       = "10.0.200.100"
      vip_hostname              = "z1-k8s-api-server"
      nginx_controller_ip       = "10.0.200.200"
      kubeconfig_file_name      = "z1-k8s.kubeconfig"
      ssh_user                  = "your_username"
      ssh_home                  = "/home/your_username"
      ssh_key_type              = "ssh-ed25519"
      pod_cidr                  = "10.42.0.0/16"
      svc_cidr                  = "10.43.0.0/16"
      containerd_version        = "1.7.13"
      runc_version              = "1.1.12"
      cni_version               = "v1.4.0"
      etcdctl_version           = "3.5.12"
      kube_vip_version          = "v0.7.0"
      cilium_version            = "v1.15.1"
      cilium_cli_version        = "v0.15.21"
      cilium_cli_arch           = "amd64"
      cilium_interface          = "^eth[0-9]+"
      hubble_version            = "v0.13.0"
      hubble_arch               = "amd64"
      metrics_server_version    = "v0.7.0"
      kube_prometheus_version   = "release-0.13"
      longhorn_chart_version    = "1.5.3"
      longhorn_nfs_storage      = "nfs://10.0.210.2:/mnt/HDD_POOL/k8s/longhorn/"
      longhorn_domain_name      = "longhorn-z1.example.com"
      longhorn_tls_secret_name  = "longhorn-z1-example.com-tls"
      grafana_domain_name       = "grafana-z1.example.com"
      grafana_tls_secret_name   = "grafana-z1-example.com-tls"
      prometheus_domain_name    = "prometheus-z1.example.com"
      prometheus_tls_secret_name= "prometheus-z1-example.com-tls"
      hubble_domain_name        = "hubble-z1.example.com"
      hubble_tls_secret_name    = "hubble-z1-example.com-tls"
#     gateway_api_version       = "v1.0.0"
      cert_manager_chart_version= "v1.14.2"
      cert_manager_email        = "your_email@email.com"
      cluster_issuer            = "staging-issuer"
      ingress_nginx_chart_version= "4.10.0"
      groundcover_enable        = false
      kubernetes_version_short  = "1.28"
      kubernetes_version_medium = "1.28.6"
      kubernetes_version_long   = "1.28.6-1.1"
      vip_interface             = "eth0"
      backup         = 1
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

