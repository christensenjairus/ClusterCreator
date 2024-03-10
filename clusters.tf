variable "cluster_name" {
  description = "The short name of the Kubernetes cluster"
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
    ssh_key_type                   : string # type of key to scan and trust for remote hosts. the key of this type gets added to local ~/.ssh/known_hosts.
    pod_cidr                       : string # cidr range for pod networking internal to cluster. Shouldn't overlap with lan network. These must differ cluster to cluster if using clustermesh.
    svc_cidr                       : string # cidr range for service networking internal to cluster. Shouldn't overlap with lan network.
    containerd_version             : string # release version of containerd
    runc_version                   : string # runc release version
    cni_version                    : string # release version of the cni plugins that are commonly installed alongside containerd
    etcdctl_version                : string # release version of etcdctl utility
    kube_vip_version               : string # kube-vip version to use. needs to be their ghcr.io docker image version
    cilium_version                 : string # release version for cilium
    cilium_cli_version             : string # version of the cilium cli
    cilium_cli_arch                : string # most likely amd64
    cilium_interface               : string # regex to match the interface that cilium should use. Usually these are the same as the lan interface(s)
    cilium_clustermesh_enabled     : bool   # whether or not to enable the cilium clustermesh. This is a feature that allows you to connect multiple clusters together. You should only need to run `cilium clustermesh connect`
    cilium_clustermesh_api_ip      : string # ip address to assign to load balancer used for clustermesh api. Should be in the same subnet as the load balancer ips.
    hubble_version                 : string # release version for hubble
    hubble_arch                    : string # most likely amd64
    metrics_server_version         : string # release version for metrics-server
    autoscaler_version             : string # release version for cluster-autoscaler. Used to figure out right branch to clone repo from. For branch cluster-autoscaler-chart-9.35.0 use 9.35.0
    kube_prometheus_version        : string # release version for kube-prometheus
    kube_dashboard_user            : string # username to use for kubernetes dashboard. To create a token to login, you'll need to run `kubectl -n kubernetes-dashboard create token <user> | pbcopy`
    kube_dashboard_version         : string # release version for kubernetes dashboard
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
    kube_dashboard_domain_name     : string # domain name to use for kubernetes dashboard ui ingress
    kube_dashboard_tls_secret_name : string # secret name for kubernetes dashboard ui ingress
    gateway_api_version            : string # version of the gateway api to install. This is more of a future-proofing thing, none of the ingresses in this project use it.
    cert_manager_chart_version     : string # helm chart version for cert-manager
    cert_manager_email             : string # your let's encrypt email for certificates
    cluster_issuer                 : string # should be either prod-issuer or staging-issuer - see ansible/helpers/clusterissuers.yaml.j2
    ingress_nginx_chart_version    : string # helm chart version for ingress-nginx
    groundcover_enable             : bool   # whether or not to install groundcover. Provided because the free tier only lets you have 1 cluster
    newrelic_enabled               : bool   # whether or not to install newrelic kubernetes connector
    newrelic_low_data_mode         : bool   # low data mode removes some less necessary data from each log record
    newrelic_scrape_system_prom    : bool   # scrape endpoints in core kube-system namespace
    newrelic_ksm_image_tag         : string # version of the newrelic ksm image to use. Normally the newrelic command they give you shows it.
    newrelic_namespace             : string # namespace to install newrelic kubernetes connector into
    kubernetes_version_short       : string # major version of kubernetes (example: 1.28)
    kubernetes_version_medium      : string # major.minor version of kubernetes (example: 1.28.6)
    kubernetes_version_long        : string # major.minor.patch version of kubernetes (example: 1.28.6-1.1)
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
    node_classes : object({
      apiserver : object({       # required type, must be >= 1.
        count    : number        # usually 3 for HA, should be an odd number. Can be 1. Should not pass 10 without editing start IPs
        cores    : number        # raise when needed, should grow as cluster grows
        sockets  : number        # on my system, the max is 2
        memory   : number        # raise when needed, should grow as cluster grows
        disk_size: number        # doesn't need to be much larger than the system os when using external etcd because all data is in etcd and control plane nodes are tainted to have no workloads
        start_ip : number        # last octet of the ip address for the first apiserver node
        labels: map(string)      # labels to apply to the nodes
      })
      etcd : object({            # required type, but can be 0.
        count    : number        # use 0 for a stacked etcd architecture. Usually 3 if you want an external etcd. Should be an odd number. Should not pass 10 without editing start IPs
        cores    : number        # raise when needed, should grow as cluster grows
        sockets  : number        # on my system, the max is 2
        memory   : number        # raise when needed, should grow as cluster grows
        disk_size: number        # doesn't need to be large, but does grow as cluster size grows
        start_ip : number        # last octet of the ip address for the first etcd node
        # no node labels because etcd nodes are external to the cluster itself
      })
      backup : object({          # custom worker type, can be 0
        count    : number        # Should not pass 10 without editing start IPs
        cores    : number        # Does not need to be large, just for backups
        sockets  : number        # on my system, the max is 2
        memory   : number        # Does not need to be large, just for backups
        disk_size: number        # For me, rule of thumb is to have same size as general nodes
        start_ip : number        # last octet of the ip address for the first backup node
        labels: map(string)      # labels to apply to the nodes
      })
      db : object({              # custom worker type, can be 0
        count    : number        # Should not pass 10 without editing start IPs
        cores    : number        # For me, rule of thumb is to make this half as much as the general nodes
        sockets  : number        # on my system, the max is 2
        memory   : number        # For me, rule of thumb is to make this as large as possible
        disk_size: number        # For me, rule of thumb is to have half the size of general nodes
        start_ip : number        # last octet of the ip address for the first db node
        labels: map(string)      # labels to apply to the nodes
      })
      general : object({         # custom worker type, can be 0
        count    : number        # Should not pass 50 without editing load balancer ip cidr and nginx ingress controller ip
        cores    : number        # For me, rule of thumb is to make this as large as possible
        sockets  : number        # on my system, the max is 2
        memory   : number        # For me, rule of thumb is to make this half as much as the db nodes
        disk_size: number        # For me, rule of thumb is to make this as large as possible
        start_ip : number        # last octet of the ip address for the first general node.
        labels: map(string)      # labels to apply to the nodes
      })
      # you can add more node classes here if you need to. You only need to add them to ansible/helpers/ansible-hosts.txt.j2
      # but don't change the name of the apiserver or etcd nodes unless you do a full find-replace in ansible.
    })
  }))
  default = { # create your clusters here using the above object
    "b1" = {
      cluster_name                   = "b1-k8s"
      cluster_id                     = 1
      vlan_id                        = 100
      cluster_subnet                 = "10.0.1"
      load_balancer_ip_block_start_1 = "10.0.1.200"
      load_balancer_ip_block_stop_1  = "10.0.1.254"
      load_balancer_ip_block_start_2 = ""
      load_balancer_ip_block_stop_2  = ""
      load_balancer_ip_block_start_3 = ""
      load_balancer_ip_block_stop_3  = ""
      load_balancer_ip_cidr_1        = ""
      load_balancer_ip_cidr_2        = ""
      load_balancer_ip_cidr_3        = ""
      load_balancer_ip_cidr_4        = ""
      load_balancer_ip_cidr_5        = ""
      vip                            = "10.0.1.100"
      vip_hostname                   = "b1-k8s-api-server"
      vip_interface                  = "eth0"
      nginx_controller_ip            = "10.0.1.200"
      kubeconfig_file_name           = "b1-k8s.yml"
      ssh_user                       = "your_username"
      ssh_home                       = "/home/your_username"
      ssh_key_type                   = "ssh-ed25519"
      pod_cidr                       = "10.10.0.0/16"
      svc_cidr                       = "10.11.0.0/16"
      containerd_version             = "1.7.13"
      runc_version                   = "1.1.12"
      cni_version                    = "v1.4.0"
      etcdctl_version                = "3.5.12"
      kube_vip_version               = "v0.7.0"
      cilium_version                 = "v1.15.1"
      cilium_cli_version             = "v0.15.21"
      cilium_cli_arch                = "amd64"
      cilium_interface               = "^eth[0-9]+"
      cilium_clustermesh_enabled     = true
      cilium_clustermesh_api_ip      = "10.0.1.254"
      hubble_version                 = "v0.13.0"
      hubble_arch                    = "amd64"
      metrics_server_version         = "v0.7.0"
      autoscaler_version             = "9.35.0"
      kube_prometheus_version        = "release-0.13"
      kube_dashboard_user            = "your_username"
      kube_dashboard_version         = "v2.7.0"
      longhorn_chart_version         = "1.5.3"
      longhorn_nfs_storage           = "nfs://10.0.1.2:/mnt/HDD_POOL/k8s/b1-k8s/longhorn/"
      longhorn_domain_name           = "longhorn-b1.your_domain.com"
      longhorn_tls_secret_name       = "longhorn-b1-your_domain.com-tls"
      grafana_domain_name            = "grafana-b1.your_domain.com"
      grafana_tls_secret_name        = "grafana-b1-your_domain.com-tls"
      prometheus_domain_name         = "prometheus-b1.your_domain.com"
      prometheus_tls_secret_name     = "prometheus-b1-your_domain.com-tls"
      hubble_domain_name             = "hubble-b1.your_domain.com"
      hubble_tls_secret_name         = "hubble-b1-your_domain.com-tls"
      kube_dashboard_domain_name     = "kubernetes-dashboard-b1.your_domain.com"
      kube_dashboard_tls_secret_name = "kubernetes-dashboard-b1-your_domain.com-tls"
      gateway_api_version            = "v1.0.0"
      cert_manager_chart_version     = "v1.14.2"
      cert_manager_email             = "your_email@gmail.com"
      cluster_issuer                 = "staging-issuer"
      ingress_nginx_chart_version    = "4.10.0"
      groundcover_enable             = false
      newrelic_enabled               = true
      newrelic_low_data_mode         = true
      newrelic_scrape_system_prom    = true
      newrelic_ksm_image_tag         = "v2.10.0"
      newrelic_namespace             = "newrelic"
      kubernetes_version_short       = "1.28"
      kubernetes_version_medium      = "1.28.6"
      kubernetes_version_long        = "1.28.6-1.1"
      backup                         = 0
      node_classes     = {
        apiserver = {
          count    = 1
          cores    = 8
          sockets  = 2
          memory   = 16384
          disk_size = 30
          start_ip   = 110
          labels = {
            "node_class" = "apiserver"
          }
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
          cores    = 1
          sockets  = 2
          memory   = 2048
          disk_size = 100
          start_ip  = 130
          labels = {
            "node_class" = "backup"
          }
        }
        db = {
          count    = 0
          cores    = 2
          sockets  = 2
          memory   = 4192
          disk_size = 50
          start_ip  = 140
          labels = {
            "node_class" = "db"
          }
        }
        general = {
          count    = 0
          cores    = 4
          sockets  = 2
          memory   = 8192
          disk_size = 100
          start_ip  = 150
          labels = {
            "node_class" = "general"
          }
        }
      }
    }
    "g1" = {
      cluster_name                   = "g1-k8s"
      cluster_id                     = 2
      vlan_id                        = 200
      vip_interface                  = "eth0"
      cluster_subnet                 = "10.0.2"
      load_balancer_ip_block_start_1 = "10.0.2.200"
      load_balancer_ip_block_stop_1  = "10.0.2.254"
      load_balancer_ip_block_start_2 = ""
      load_balancer_ip_block_stop_2  = ""
      load_balancer_ip_block_start_3 = ""
      load_balancer_ip_block_stop_3  = ""
      load_balancer_ip_cidr_1        = ""
      load_balancer_ip_cidr_2        = ""
      load_balancer_ip_cidr_3        = ""
      load_balancer_ip_cidr_4        = ""
      load_balancer_ip_cidr_5        = ""
      vip                            = "10.0.2.100"
      vip_hostname                   = "g1-k8s-api-server"
      nginx_controller_ip            = "10.0.2.200"
      kubeconfig_file_name           = "g1-k8s.yml"
      ssh_user                       = "your_username"
      ssh_home                       = "/home/your_username"
      ssh_key_type                   = "ssh-ed25519"
      pod_cidr                       = "10.20.0.0/16"
      svc_cidr                       = "10.21.0.0/16"
      containerd_version             = "1.7.13"
      runc_version                   = "1.1.12"
      cni_version                    = "v1.4.0"
      etcdctl_version                = "3.5.12"
      kube_vip_version               = "v0.7.0"
      cilium_version                 = "v1.15.1"
      cilium_cli_version             = "v0.15.21"
      cilium_cli_arch                = "amd64"
      cilium_interface               = "^eth[0-9]+"
      cilium_clustermesh_enabled     = true
      cilium_clustermesh_api_ip      = "10.0.2.254"
      hubble_version                 = "v0.13.0"
      hubble_arch                    = "amd64"
      metrics_server_version         = "v0.7.0"
      autoscaler_version             = "9.35.0"
      kube_prometheus_version        = "release-0.13"
      kube_dashboard_user            = "your_username"
      kube_dashboard_version         = "v2.7.0"
      longhorn_chart_version         = "1.5.3"
      longhorn_nfs_storage           = "nfs://10.0.2.2:/mnt/HDD_POOL/k8s/g1-k8s/longhorn/"
      longhorn_domain_name           = "longhorn-g1.your_domain.com"
      longhorn_tls_secret_name       = "longhorn-g1-your_domain.com-tls"
      grafana_domain_name            = "grafana-g1.your_domain.com"
      grafana_tls_secret_name        = "grafana-g1-your_domain.com-tls"
      prometheus_domain_name         = "prometheus-g1.your_domain.com"
      prometheus_tls_secret_name     = "prometheus-g1-your_domain.com-tls"
      hubble_domain_name             = "hubble-g1.your_domain.com"
      hubble_tls_secret_name         = "hubble-g1-your_domain.com-tls"
      kube_dashboard_domain_name     = "kubernetes-dashboard-g1.your_domain.com"
      kube_dashboard_tls_secret_name = "kubernetes-dashboard-g1-your_domain.com-tls"
      gateway_api_version            = "v1.0.0"
      cert_manager_chart_version     = "v1.14.2"
      cert_manager_email             = "your_email@gmail.com"
      cluster_issuer                 = "staging-issuer"
      ingress_nginx_chart_version    = "4.10.0"
      groundcover_enable             = false
      newrelic_enabled               = true
      newrelic_low_data_mode         = true
      newrelic_scrape_system_prom    = true
      newrelic_ksm_image_tag         = "v2.10.0"
      newrelic_namespace             = "newrelic"
      kubernetes_version_short       = "1.28"
      kubernetes_version_medium      = "1.28.6"
      kubernetes_version_long        = "1.28.6-1.1"
      backup                         = 0
      node_classes     = {
        apiserver = {
          count    = 1
          cores    = 2
          sockets  = 2
          memory   = 4096
          disk_size = 30
          start_ip  = 110
          labels = {
            "node_class" = "apiserver"
          }
        }
        etcd = {
          count    = 0
          cores    = 1
          sockets  = 2
          memory   = 2048
          disk_size = 30
          start_ip  = 120
        }
        backup = {
          count    = 1
          cores    = 1
          sockets  = 2
          memory   = 2048
          disk_size = 100
          start_ip  = 130
          labels = {
            "node_class" = "backup"
          }
        }
        db = {
          count    = 1
          cores    = 2
          sockets  = 2
          memory   = 8192
          disk_size = 50
          start_ip  = 140
          labels = {
            "node_class" = "db"
          }
        }
        general = {
          count    = 1
          cores    = 4
          sockets  = 2
          memory   = 4096
          disk_size = 100
          start_ip  = 150
          labels = {
            "node_class" = "general"
          }
        }
      }
    }
    "z1" = {
      cluster_name                   = "z1-k8s"
      cluster_id                     = 3
      vlan_id                        = 300
      cluster_subnet                 = "10.0.3"
      load_balancer_ip_block_start_1 = "10.0.3.200"
      load_balancer_ip_block_stop_1  = "10.0.3.254"
      load_balancer_ip_block_start_2 = ""
      load_balancer_ip_block_stop_2  = ""
      load_balancer_ip_block_start_3 = ""
      load_balancer_ip_block_stop_3  = ""
      load_balancer_ip_cidr_1        = ""
      load_balancer_ip_cidr_2        = ""
      load_balancer_ip_cidr_3        = ""
      load_balancer_ip_cidr_4        = ""
      load_balancer_ip_cidr_5        = ""
      vip                            = "10.0.3.100"
      vip_hostname                   = "z1-k8s-api-server"
      vip_interface                  = "eth0"
      nginx_controller_ip            = "10.0.3.200"
      kubeconfig_file_name           = "z1-k8s.yml"
      ssh_user                       = "your_username"
      ssh_home                       = "/home/your_username"
      ssh_key_type                   = "ssh-ed25519"
      pod_cidr                       = "10.30.0.0/16"
      svc_cidr                       = "10.31.0.0/16"
      containerd_version             = "1.7.13"
      runc_version                   = "1.1.12"
      cni_version                    = "v1.4.0"
      etcdctl_version                = "3.5.12"
      kube_vip_version               = "v0.7.0"
      cilium_version                 = "v1.15.1"
      cilium_cli_version             = "v0.15.21"
      cilium_cli_arch                = "amd64"
      cilium_interface               = "^eth[0-9]+"
      cilium_clustermesh_enabled     = true
      cilium_clustermesh_api_ip      = "10.0.3.254"
      hubble_version                 = "v0.13.0"
      hubble_arch                    = "amd64"
      metrics_server_version         = "v0.7.0"
      autoscaler_version             = "9.35.0"
      kube_prometheus_version        = "release-0.13"
      kube_dashboard_user            = "your_username"
      kube_dashboard_version         = "v2.7.0"
      longhorn_chart_version         = "1.5.3"
      longhorn_nfs_storage           = "nfs://10.0.3.2:/mnt/HDD_POOL/k8s/z1-k8s/longhorn/"
      longhorn_domain_name           = "longhorn-z1.your_domain.com"
      longhorn_tls_secret_name       = "longhorn-z1-your_domain.com-tls"
      grafana_domain_name            = "grafana-z1.your_domain.com"
      grafana_tls_secret_name        = "grafana-z1-your_domain.com-tls"
      prometheus_domain_name         = "prometheus-z1.your_domain.com"
      prometheus_tls_secret_name     = "prometheus-z1-your_domain.com-tls"
      hubble_domain_name             = "hubble-z1.your_domain.com"
      hubble_tls_secret_name         = "hubble-z1-your_domain.com-tls"
      kube_dashboard_domain_name     = "kubernetes-dashboard-z1.your_domain.com"
      kube_dashboard_tls_secret_name = "kubernetes-dashboard-z1-your_domain.com-tls"
      gateway_api_version            = "v1.0.0"
      cert_manager_chart_version     = "v1.14.2"
      cert_manager_email             = "your_email@gmail.com"
      cluster_issuer                 = "prod-issuer"
      ingress_nginx_chart_version    = "4.10.0"
      groundcover_enable             = false
      newrelic_enabled               = true
      newrelic_low_data_mode         = false
      newrelic_scrape_system_prom    = true
      newrelic_ksm_image_tag         = "v2.10.0"
      newrelic_namespace             = "newrelic"
      kubernetes_version_short       = "1.28"
      kubernetes_version_medium      = "1.28.6"
      kubernetes_version_long        = "1.28.6-1.1"
      backup                         = 1
      node_classes     = {
        apiserver = {
          count    = 3
          cores    = 2
          sockets  = 2
          memory   = 4096
          disk_size= 30
          start_ip = 110
          labels   = {
            "node_class" = "apiserver"
          }
        }
        etcd = {
          count    = 3
          cores    = 1
          sockets  = 2
          memory   = 2048
          disk_size= 30
          start_ip = 120
        }
        backup = {
          count    = 2
          cores    = 1
          sockets  = 2
          memory   = 2048
          disk_size= 100
          start_ip = 130
          labels   = {
            "node_class" = "backup"
          }
        }
        db = {
          count    = 3
          cores    = 4
          sockets  = 2
          memory   = 16384
          disk_size= 50
          start_ip = 140
          labels   = {
            "node_class" = "db"
          }
        }
        general = {
          count    = 5
          cores    = 8
          sockets  = 2
          memory   = 8192
          disk_size= 100
          start_ip = 150
          labels   = {
            "node_class" = "general"
          }
        }
      }
    }
  }
}

