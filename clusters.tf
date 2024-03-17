variable "cluster_name" {
  description = "The short name of the Kubernetes cluster"
  type        = string
  default     = "g1"
}

variable "clusters" {
  description = "Configuration details for each cluster."
  type = map(object({
    cluster_name                     : string # name to be used in kubeconfig, cluster mesh, network name, k8s_vm_template pool
    cluster_id                       : number # acts as the vm_id prefix. Also used for cluster mesh.
    kubeconfig_file_name             : string # name of the local kubeconfig file to be created. Assumed this will be in $HOME/.kube/
    ssh                              : object({
      ssh_user                       : string # username for the remote server
      ssh_home                       : string # path to your home directory on the remote server
      ssh_key_type                   : string # type of key to scan and trust for remote hosts. the key of this type gets added to local ~/.ssh/known_hosts.
    })
    host_networking                  : object({
      vlan_id                        : number # vlan id for the cluster. See README on how to not use vlans
      cluster_subnet                 : string # first three octets of the network's subnet (assuming its a /24)
      dns1                           : string # primary dns server for vm hosts
      dns2                           : string # secondary dns server for vm hosts
    })
    cluster_networking               : object({
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
      cilium_interface               : string # regex to match the interface that cilium should use. Usually these are the same as the lan interface(s)
      cilium_clustermesh_enabled     : string # boolean. whether or not to enable the cilium clustermesh. This is a feature that allows you to connect multiple clusters together. You should only need to run `cilium clustermesh connect`
      cilium_clustermesh_api_ip      : string # ip address to assign to load balancer used for clustermesh api. Should be in the same subnet as the load balancer ips.
      hubble_domain_name             : string # domain name to use for hubble ui ingress
      hubble_tls_secret_name         : string # secret name for longhorn ui ingress
      gateway_api_version            : string # version of the gateway api to install. This is more of a future-proofing thing, none of the ingresses in this project use it.
      load_balancer_ip_block_start_1 : string # L2 arp announcements by cilium. Need to add 'L2Announcement': true to any LB class that needs an external IP.
      load_balancer_ip_block_stop_1  : string # must have both start and stop defined or neither will be used
      load_balancer_ip_block_start_2 : string # any of these can be blank if not in use
      load_balancer_ip_block_stop_2  : string
      load_balancer_ip_cidr_1        : string # any of these can be blank if not in use
      load_balancer_ip_cidr_2        : string #
    })
    local_path_provisioner           : object({
      local_path_provisioner_version : string # version for Rancher's local path provisioner
    })
    metrics_server                   : object({
      metrics_server_version         : string # release version for metrics-server
    })
    vertical_autoscaler              : object({
      autoscaler_version             : string # release version for cluster-autoscaler. Used to figure out right branch to clone repo from. For branch cluster-autoscaler-chart-9.35.0 use 9.35.0
    })
    cert_manager                     : object({
      cert_manager_chart_version     : string # helm chart version for cert-manager
      cert_manager_email             : string # your let's encrypt email for certificates
      cluster_issuer                 : string # should be either prod-issuer or staging-issuer - see ansible/helpers/clusterissuers.yaml.j2. Your certs will not be trusted with the staging issuer.
    })
    longhorn                         : object({
      longhorn_chart_version         : string # helm chart version for longhorn
      longhorn_nfs_storage           : string # I use TrueNAS with another network device with the associated vlan tag.
      longhorn_domain_name           : string # domain name to use for longhorn ui ingress
      longhorn_tls_secret_name       : string # secret name for longhorn ui ingress
    })
    ingress_nginx                    : object({
      ingress_nginx_chart_version    : string # helm chart version for ingress-nginx
      nginx_controller_external_ip   : string # IP for external hosts to connect to to reach ingress resources. must be inside one if your load balancer ip cidr ranges
      nginx_controller_internal_ip   : string # IP for internal services to connect to to reach ingress resources. must be inside one if your load balancer ip cidr ranges
    })
    kube_prometheus_stack            : object({
      kube_prometheus_stack_version  : string # helm chart version for kube-prometheus from prometheus-community helm repo
      grafana_domain_name            : string # domain name to use for grafana ui ingress
      grafana_tls_secret_name        : string # secret name for grafana ui ingress
      prometheus_domain_name         : string # domain name to use for prometheus ui ingress
      prometheus_tls_secret_name     : string # secret name for prometheus ui ingress
      alert_manager_domain_name      : string # domain name to use for alert manager ui ingress
      alert_manager_tls_secret_name  : string # secret name for alert manager ui ingress
      alert_manager_slack_channel    : string # slack channel to send alerts to. Must already be created and have bot invited to channel.
    })
    kube_dashboard                   : object({
      kube_dashboard_user            : string # username to use for kubernetes dashboard. To create a token to login, you'll need to run `kubectl -n kubernetes-dashboard create token <user> | pbcopy`
      kube_dashboard_version         : string # release version for kubernetes dashboard
      kube_dashboard_domain_name     : string # domain name to use for kubernetes dashboard ui ingress
      kube_dashboard_tls_secret_name : string # secret name for kubernetes dashboard ui ingress
    })
    newrelic                         : object({
      newrelic_low_data_mode         : string # boolean. low data mode removes some less necessary data from each log record
      newrelic_scrape_system_prom    : string # boolean. scrape endpoints in core kube-system namespace
      newrelic_ksm_image_tag         : string # version of the newrelic ksm image to use. Normally the newrelic command they give you shows it.
      newrelic_namespace             : string # namespace to install newrelic kubernetes connector into
    })
    node_classes : object({
      apiserver  : object({      # required type, must be >= 1.
        count    : number        # usually 3 for HA, should be an odd number. Can be 1. Should not pass 10 without editing start IPs
        cores    : number        # raise when needed, should grow as cluster grows
        sockets  : number        # on my system, the max is 2
        memory   : number        # raise when needed, should grow as cluster grows
        disk_size: number        # doesn't need to be much larger than the system os when using external etcd because all data is in etcd and control plane nodes are tainted to have no workloads
        start_ip : number        # last octet of the ip address for the first apiserver node
        labels   : map(string)   # labels to apply to the nodes
      })
      etcd       : object({      # required type, but can be 0.
        count    : number        # use 0 for a stacked etcd architecture. Usually 3 if you want an external etcd. Should be an odd number. Should not pass 10 without editing start IPs
        cores    : number        # raise when needed, should grow as cluster grows
        sockets  : number        # on my system, the max is 2
        memory   : number        # raise when needed, should grow as cluster grows
        disk_size: number        # doesn't need to be large, but does grow as cluster size grows
        start_ip : number        # last octet of the ip address for the first etcd node
        # no node labels because etcd nodes are external to the cluster itself
      })
      backup     : object({      # custom worker type, can be 0
        count    : number        # Should not pass 10 without editing start IPs
        cores    : number        # Does not need to be large, just for backups
        sockets  : number        # on my system, the max is 2
        memory   : number        # Does not need to be large, just for backups
        disk_size: number        # For me, rule of thumb is to have same size as general nodes
        start_ip : number        # last octet of the ip address for the first backup node
        labels   : map(string)   # labels to apply to the nodes
      })
      db         : object({      # custom worker type, can be 0
        count    : number        # Should not pass 10 without editing start IPs
        cores    : number        # For me, rule of thumb is to make this half as much as the general nodes
        sockets  : number        # on my system, the max is 2
        memory   : number        # For me, rule of thumb is to make this as large as possible
        disk_size: number        # For me, rule of thumb is to have half the size of general nodes
        start_ip : number        # last octet of the ip address for the first db node
        labels   : map(string)   # labels to apply to the nodes
      })
      general    : object({      # custom worker type, can be 0
        count    : number        # Should not pass 50 without editing load balancer ip cidr and nginx ingress controller ip
        cores    : number        # For me, rule of thumb is to make this as large as possible
        sockets  : number        # on my system, the max is 2
        memory   : number        # For me, rule of thumb is to make this half as much as the db nodes
        disk_size: number        # For me, rule of thumb is to make this as large as possible
        start_ip : number        # last octet of the ip address for the first general node.
        labels   : map(string)   # labels to apply to the nodes
      })
      # you can add more node classes here if you need to. You only need to add them to ansible/helpers/ansible_hosts.txt.j2
      # but don't change the name of the apiserver or etcd nodes unless you do a full find-replace in ansible.
    })
  }))
  default = { # create your clusters here using the above object
    "b1" = {
      cluster_name                     = "b1-k8s"
      cluster_id                       = 1
      kubeconfig_file_name             = "b1-k8s.yml"
      ssh = {
        ssh_user                       = "your_username"
        ssh_home                       = "/home/your_username"
        ssh_key_type                   = "ssh-ed25519"
      }
      host_networking                  = {
        vlan_id                        = 100
        cluster_subnet                 = "10.0.1"
        dns1                           = "10.0.1.3"
        dns2                           = "10.0.1.4"
      }
      cluster_networking = {
        pod_cidr                       = "10.10.0.0/16"
        svc_cidr                       = "10.11.0.0/16"
      }
      kube_vip = {
        kube_vip_version               = "0.7.0"
        vip                            = "10.0.1.100"
        vip_hostname                   = "b1-k8s-api-server"
        vip_interface                  = "eth0"
      }
      cilium = {
        cilium_version                 = "1.15.1"
        cilium_interface               = "^eth[0-9]+"
        cilium_clustermesh_enabled     = "false"
        cilium_clustermesh_api_ip      = "10.0.1.254"
        hubble_domain_name             = "hubble-b1.your_domain.com"
        hubble_tls_secret_name         = "hubble-b1-your_domain.com-tls"
        gateway_api_version            = "1.0.0"
        load_balancer_ip_block_start_1 = "10.0.1.200"
        load_balancer_ip_block_stop_1  = "10.0.1.254"
        load_balancer_ip_block_start_2 = ""
        load_balancer_ip_block_stop_2  = ""
        load_balancer_ip_cidr_1        = ""
        load_balancer_ip_cidr_2        = ""
      }
      local_path_provisioner = {
        local_path_provisioner_version = "0.0.26"
      }
      metrics_server = {
        metrics_server_version         = "0.7.0"
      }
      vertical_autoscaler = {
        autoscaler_version             = "9.35.0"
      }
      cert_manager = {
        cert_manager_chart_version     = "1.14.2"
        cert_manager_email             = "your_email@gmail.com"
        cluster_issuer                 = "staging-issuer"
      }
      longhorn = {
        longhorn_chart_version         = "1.5.4"
        longhorn_nfs_storage           = "nfs://10.0.1.2:/mnt/HDD_POOL/k8s/b1-k8s/longhorn/"
        longhorn_domain_name           = "longhorn-b1.your_domain.com"
        longhorn_tls_secret_name       = "longhorn-b1-your_domain.com-tls"
      }
      ingress_nginx = {
        ingress_nginx_chart_version    = "4.10.0"
        nginx_controller_external_ip   = "10.0.1.200"
        nginx_controller_internal_ip   = "10.0.1.201"
      }
      kube_prometheus_stack = {
        kube_prometheus_stack_version  = "57.0.1"
        grafana_domain_name            = "grafana-b1.your_domain.com"
        grafana_tls_secret_name        = "grafana-b1-your_domain.com-tls"
        prometheus_domain_name         = "prometheus-b1.your_domain.com"
        prometheus_tls_secret_name     = "prometheus-b1-your_domain.com-tls"
        alert_manager_domain_name      = "alert-manager-b1.your_domain.com"
        alert_manager_tls_secret_name  = "alert-manager-b1-your_domain.com-tls"
        alert_manager_slack_channel    = "b1-alerts"
      }
      kube_dashboard = {
        kube_dashboard_user            = "your_username"
        kube_dashboard_version         = "2.7.0"
        kube_dashboard_domain_name     = "kubernetes-dashboard-b1.your_domain.com"
        kube_dashboard_tls_secret_name = "kubernetes-dashboard-b1-your_domain.com-tls"
      }
      newrelic = {
        newrelic_low_data_mode         = "true"
        newrelic_scrape_system_prom    = "true"
        newrelic_ksm_image_tag         = "2.10.0"
        newrelic_namespace             = "newrelic"
      }
      node_classes = {
        apiserver = {
          count      = 1
          cores      = 8
          sockets    = 2
          memory     = 16384
          disk_size  = 100
          start_ip   = 110
          labels = {
            "node_class" = "apiserver"
          }
        }
        etcd = {
          count      = 0
          cores      = 1
          sockets    = 2
          memory     = 2048
          disk_size  = 30
          start_ip   = 120
        }
        backup = {
          count      = 0
          cores      = 1
          sockets    = 2
          memory     = 2048
          disk_size  = 100
          start_ip   = 130
          labels = {
            "node_class" = "backup"
          }
        }
        db = {
          count      = 0
          cores      = 2
          sockets    = 2
          memory     = 8192
          disk_size  = 50
          start_ip   = 140
          labels = {
            "node_class" = "db"
          }
        }
        general = {
          count      = 0
          cores      = 4
          sockets    = 2
          memory     = 4192
          disk_size  = 100
          start_ip   = 150
          labels = {
            "node_class" = "general"
          }
        }
      }
    }
    "b2" = {
      cluster_name                     = "b2-k8s"
      cluster_id                       = 2
      kubeconfig_file_name             = "b2-k8s.yml"
      ssh = {
        ssh_user                       = "your_username"
        ssh_home                       = "/home/your_username"
        ssh_key_type                   = "ssh-ed25519"
      }
      host_networking                  = {
        vlan_id                        = 200
        cluster_subnet                 = "10.0.2"
        dns1                           = "10.0.2.3"
        dns2                           = "10.0.2.4"
      }
      cluster_networking = {
        pod_cidr                       = "10.10.0.0/16"
        svc_cidr                       = "10.11.0.0/16"
      }
      kube_vip = {
        kube_vip_version               = "0.7.0"
        vip                            = "10.0.2.100"
        vip_hostname                   = "b2-k8s-api-server"
        vip_interface                  = "eth0"
      }
      cilium = {
        cilium_version                 = "1.15.1"
        cilium_interface               = "^eth[0-9]+"
        cilium_clustermesh_enabled     = "false"
        cilium_clustermesh_api_ip      = "10.0.2.254"
        hubble_domain_name             = "hubble-b2.your_domain.com"
        hubble_tls_secret_name         = "hubble-b2-your_domain.com-tls"
        gateway_api_version            = "1.0.0"
        load_balancer_ip_block_start_1 = "10.0.2.200"
        load_balancer_ip_block_stop_1  = "10.0.2.254"
        load_balancer_ip_block_start_2 = ""
        load_balancer_ip_block_stop_2  = ""
        load_balancer_ip_cidr_1        = ""
        load_balancer_ip_cidr_2        = ""
      }
      local_path_provisioner = {
        local_path_provisioner_version = "0.0.26"
      }
      metrics_server = {
        metrics_server_version         = "0.7.0"
      }
      vertical_autoscaler = {
        autoscaler_version             = "9.35.0"
      }
      cert_manager = {
        cert_manager_chart_version     = "1.14.2"
        cert_manager_email             = "your_email@gmail.com"
        cluster_issuer                 = "staging-issuer"
      }
      longhorn = {
        longhorn_chart_version         = "1.5.4"
        longhorn_nfs_storage           = "nfs://10.0.2.2:/mnt/HDD_POOL/k8s/b2-k8s/longhorn/"
        longhorn_domain_name           = "longhorn-b2.your_domain.com"
        longhorn_tls_secret_name       = "longhorn-b2-your_domain.com-tls"
      }
      ingress_nginx = {
        ingress_nginx_chart_version    = "4.10.0"
        nginx_controller_external_ip   = "10.0.2.200"
        nginx_controller_internal_ip   = "10.0.2.201"
      }
      kube_prometheus_stack = {
        kube_prometheus_stack_version  = "57.0.1"
        grafana_domain_name            = "grafana-b2.your_domain.com"
        grafana_tls_secret_name        = "grafana-b2-your_domain.com-tls"
        prometheus_domain_name         = "prometheus-b2.your_domain.com"
        prometheus_tls_secret_name     = "prometheus-b2-your_domain.com-tls"
        alert_manager_domain_name      = "alert-manager-b2.your_domain.com"
        alert_manager_tls_secret_name  = "alert-manager-b2-your_domain.com-tls"
        alert_manager_slack_channel    = "b2-alerts"
      }
      kube_dashboard = {
        kube_dashboard_user            = "your_username"
        kube_dashboard_version         = "2.7.0"
        kube_dashboard_domain_name     = "kubernetes-dashboard-b2.your_domain.com"
        kube_dashboard_tls_secret_name = "kubernetes-dashboard-b2-your_domain.com-tls"
      }
      newrelic = {
        newrelic_low_data_mode         = "true"
        newrelic_scrape_system_prom    = "true"
        newrelic_ksm_image_tag         = "2.10.0"
        newrelic_namespace             = "newrelic"
      }
      node_classes = {
        apiserver = {
          count      = 1
          cores      = 8
          sockets    = 2
          memory     = 16384
          disk_size  = 100
          start_ip   = 110
          labels = {
            "node_class" = "apiserver"
          }
        }
        etcd = {
          count      = 0
          cores      = 1
          sockets    = 2
          memory     = 2048
          disk_size  = 30
          start_ip   = 120
        }
        backup = {
          count      = 0
          cores      = 1
          sockets    = 2
          memory     = 2048
          disk_size  = 100
          start_ip   = 130
          labels = {
            "node_class" = "backup"
          }
        }
        db = {
          count      = 0
          cores      = 2
          sockets    = 2
          memory     = 8192
          disk_size  = 50
          start_ip   = 140
          labels = {
            "node_class" = "db"
          }
        }
        general = {
          count      = 0
          cores      = 4
          sockets    = 2
          memory     = 4192
          disk_size  = 100
          start_ip   = 150
          labels = {
            "node_class" = "general"
          }
        }
      }
    }
    "g1" = {
      cluster_name                     = "g1-k8s"
      cluster_id                       = 3
      kubeconfig_file_name             = "g1-k8s.yml"
      ssh = {
        ssh_user                       = "your_username"
        ssh_home                       = "/home/your_username"
        ssh_key_type                   = "ssh-ed25519"
      }
      host_networking                  = {
        vlan_id                        = 300
        cluster_subnet                 = "10.0.3"
        dns1                           = "10.0.3.3"
        dns2                           = "10.0.3.4"
      }
      cluster_networking = {
        pod_cidr                       = "10.10.0.0/16"
        svc_cidr                       = "10.11.0.0/16"
      }
      kube_vip = {
        kube_vip_version               = "0.7.0"
        vip                            = "10.0.3.100"
        vip_hostname                   = "g1-k8s-api-server"
        vip_interface                  = "eth0"
      }
      cilium = {
        cilium_version                 = "1.15.1"
        cilium_interface               = "^eth[0-9]+"
        cilium_clustermesh_enabled     = "false"
        cilium_clustermesh_api_ip      = "10.0.3.254"
        hubble_domain_name             = "hubble-g1.your_domain.com"
        hubble_tls_secret_name         = "hubble-g1-your_domain.com-tls"
        gateway_api_version            = "1.0.0"
        load_balancer_ip_block_start_1 = "10.0.3.200"
        load_balancer_ip_block_stop_1  = "10.0.3.254"
        load_balancer_ip_block_start_2 = ""
        load_balancer_ip_block_stop_2  = ""
        load_balancer_ip_cidr_1        = ""
        load_balancer_ip_cidr_2        = ""
      }
      local_path_provisioner = {
        local_path_provisioner_version = "0.0.26"
      }
      metrics_server = {
        metrics_server_version         = "0.7.0"
      }
      vertical_autoscaler = {
        autoscaler_version             = "9.35.0"
      }
      cert_manager = {
        cert_manager_chart_version     = "1.14.2"
        cert_manager_email             = "your_email@gmail.com"
        cluster_issuer                 = "staging-issuer"
      }
      longhorn = {
        longhorn_chart_version         = "1.5.4"
        longhorn_nfs_storage           = "nfs://10.0.3.2:/mnt/HDD_POOL/k8s/g1-k8s/longhorn/"
        longhorn_domain_name           = "longhorn-g1.your_domain.com"
        longhorn_tls_secret_name       = "longhorn-g1-your_domain.com-tls"
      }
      ingress_nginx = {
        ingress_nginx_chart_version    = "4.10.0"
        nginx_controller_external_ip   = "10.0.3.200"
        nginx_controller_internal_ip   = "10.0.3.201"
      }
      kube_prometheus_stack = {
        kube_prometheus_stack_version  = "57.0.1"
        grafana_domain_name            = "grafana-g1.your_domain.com"
        grafana_tls_secret_name        = "grafana-g1-your_domain.com-tls"
        prometheus_domain_name         = "prometheus-g1.your_domain.com"
        prometheus_tls_secret_name     = "prometheus-g1-your_domain.com-tls"
        alert_manager_domain_name      = "alert-manager-g1.your_domain.com"
        alert_manager_tls_secret_name  = "alert-manager-g1-your_domain.com-tls"
        alert_manager_slack_channel    = "g1-alerts"
      }
      kube_dashboard = {
        kube_dashboard_user            = "your_username"
        kube_dashboard_version         = "2.7.0"
        kube_dashboard_domain_name     = "kubernetes-dashboard-g1.your_domain.com"
        kube_dashboard_tls_secret_name = "kubernetes-dashboard-g1-your_domain.com-tls"
      }
      newrelic = {
        newrelic_low_data_mode         = "true"
        newrelic_scrape_system_prom    = "true"
        newrelic_ksm_image_tag         = "2.10.0"
        newrelic_namespace             = "newrelic"
      }
      node_classes = {
        apiserver = {
          count      = 1
          cores      = 2
          sockets    = 2
          memory     = 2048
          disk_size  = 30
          start_ip   = 110
          labels = {
            "node_class" = "apiserver"
          }
        }
        etcd = {
          count      = 0
          cores      = 1
          sockets    = 2
          memory     = 2048
          disk_size  = 30
          start_ip   = 120
        }
        backup = {
          count      = 1
          cores      = 1
          sockets    = 2
          memory     = 2048
          disk_size  = 100
          start_ip   = 130
          labels = {
            "node_class" = "backup"
          }
        }
        db = {
          count      = 1
          cores      = 2
          sockets    = 2
          memory     = 8192
          disk_size  = 50
          start_ip   = 140
          labels = {
            "node_class" = "db"
          }
        }
        general = {
          count      = 1
          cores      = 4
          sockets    = 2
          memory     = 4192
          disk_size  = 100
          start_ip   = 150
          labels = {
            "node_class" = "general"
          }
        }
      }
    }
    "g2" = {
      cluster_name                     = "g2-k8s"
      cluster_id                       = 4
      kubeconfig_file_name             = "g2-k8s.yml"
      ssh = {
        ssh_user                       = "your_username"
        ssh_home                       = "/home/your_username"
        ssh_key_type                   = "ssh-ed25519"
      }
      host_networking                  = {
        vlan_id                        = 400
        cluster_subnet                 = "10.0.4"
        dns1                           = "10.0.4.3"
        dns2                           = "10.0.4.4"
      }
      cluster_networking = {
        pod_cidr                       = "10.10.0.0/16"
        svc_cidr                       = "10.11.0.0/16"
      }
      kube_vip = {
        kube_vip_version               = "0.7.0"
        vip                            = "10.0.4.100"
        vip_hostname                   = "g2-k8s-api-server"
        vip_interface                  = "eth0"
      }
      cilium = {
        cilium_version                 = "1.15.1"
        cilium_interface               = "^eth[0-9]+"
        cilium_clustermesh_enabled     = "false"
        cilium_clustermesh_api_ip      = "10.0.4.254"
        hubble_domain_name             = "hubble-g2.your_domain.com"
        hubble_tls_secret_name         = "hubble-g2-your_domain.com-tls"
        gateway_api_version            = "1.0.0"
        load_balancer_ip_block_start_1 = "10.0.4.200"
        load_balancer_ip_block_stop_1  = "10.0.4.254"
        load_balancer_ip_block_start_2 = ""
        load_balancer_ip_block_stop_2  = ""
        load_balancer_ip_cidr_1        = ""
        load_balancer_ip_cidr_2        = ""
      }
      local_path_provisioner = {
        local_path_provisioner_version = "0.0.26"
      }
      metrics_server = {
        metrics_server_version         = "0.7.0"
      }
      vertical_autoscaler = {
        autoscaler_version             = "9.35.0"
      }
      cert_manager = {
        cert_manager_chart_version     = "1.14.2"
        cert_manager_email             = "your_email@gmail.com"
        cluster_issuer                 = "staging-issuer"
      }
      longhorn = {
        longhorn_chart_version         = "1.5.4"
        longhorn_nfs_storage           = "nfs://10.0.4.2:/mnt/HDD_POOL/k8s/g2-k8s/longhorn/"
        longhorn_domain_name           = "longhorn-g2.your_domain.com"
        longhorn_tls_secret_name       = "longhorn-g2-your_domain.com-tls"
      }
      ingress_nginx = {
        ingress_nginx_chart_version    = "4.10.0"
        nginx_controller_external_ip   = "10.0.4.200"
        nginx_controller_internal_ip   = "10.0.4.201"
      }
      kube_prometheus_stack = {
        kube_prometheus_stack_version  = "57.0.1"
        grafana_domain_name            = "grafana-g2.your_domain.com"
        grafana_tls_secret_name        = "grafana-g2-your_domain.com-tls"
        prometheus_domain_name         = "prometheus-g2.your_domain.com"
        prometheus_tls_secret_name     = "prometheus-g2-your_domain.com-tls"
        alert_manager_domain_name      = "alert-manager-g2.your_domain.com"
        alert_manager_tls_secret_name  = "alert-manager-g2-your_domain.com-tls"
        alert_manager_slack_channel    = "g2-alerts"
      }
      kube_dashboard = {
        kube_dashboard_user            = "your_username"
        kube_dashboard_version         = "2.7.0"
        kube_dashboard_domain_name     = "kubernetes-dashboard-g2.your_domain.com"
        kube_dashboard_tls_secret_name = "kubernetes-dashboard-g2-your_domain.com-tls"
      }
      newrelic = {
        newrelic_low_data_mode         = "true"
        newrelic_scrape_system_prom    = "true"
        newrelic_ksm_image_tag         = "2.10.0"
        newrelic_namespace             = "newrelic"
      }
      node_classes = {
        apiserver = {
          count      = 1
          cores      = 2
          sockets    = 2
          memory     = 2048
          disk_size  = 30
          start_ip   = 110
          labels = {
            "node_class" = "apiserver"
          }
        }
        etcd = {
          count      = 0
          cores      = 1
          sockets    = 2
          memory     = 2048
          disk_size  = 30
          start_ip   = 120
        }
        backup = {
          count      = 1
          cores      = 1
          sockets    = 2
          memory     = 2048
          disk_size  = 100
          start_ip   = 130
          labels = {
            "node_class" = "backup"
          }
        }
        db = {
          count      = 1
          cores      = 2
          sockets    = 2
          memory     = 8192
          disk_size  = 50
          start_ip   = 140
          labels = {
            "node_class" = "db"
          }
        }
        general = {
          count      = 1
          cores      = 4
          sockets    = 2
          memory     = 4192
          disk_size  = 100
          start_ip   = 150
          labels = {
            "node_class" = "general"
          }
        }
      }
    }
    "z1" = {
      cluster_name                     = "z1-k8s"
      cluster_id                       = 5
      kubeconfig_file_name             = "z1-k8s.yml"
      ssh = {
        ssh_user                       = "your_username"
        ssh_home                       = "/home/your_username"
        ssh_key_type                   = "ssh-ed25519"
      }
      host_networking                  = {
        vlan_id                        = 500
        cluster_subnet                 = "10.0.5"
        dns1                           = "10.0.5.3"
        dns2                           = "10.0.5.4"
      }
      cluster_networking = {
        pod_cidr                       = "10.10.0.0/16"
        svc_cidr                       = "10.11.0.0/16"
      }
      kube_vip = {
        kube_vip_version               = "0.7.0"
        vip                            = "10.0.5.100"
        vip_hostname                   = "z1-k8s-api-server"
        vip_interface                  = "eth0"
      }
      cilium = {
        cilium_version                 = "1.15.1"
        cilium_interface               = "^eth[0-9]+"
        cilium_clustermesh_enabled     = "false"
        cilium_clustermesh_api_ip      = "10.0.5.254"
        hubble_domain_name             = "hubble-z1.your_domain.com"
        hubble_tls_secret_name         = "hubble-z1-your_domain.com-tls"
        gateway_api_version            = "1.0.0"
        load_balancer_ip_block_start_1 = "10.0.5.200"
        load_balancer_ip_block_stop_1  = "10.0.5.254"
        load_balancer_ip_block_start_2 = ""
        load_balancer_ip_block_stop_2  = ""
        load_balancer_ip_cidr_1        = ""
        load_balancer_ip_cidr_2        = ""
      }
      local_path_provisioner = {
        local_path_provisioner_version = "0.0.26"
      }
      metrics_server = {
        metrics_server_version         = "0.7.0"
      }
      vertical_autoscaler = {
        autoscaler_version             = "9.35.0"
      }
      cert_manager = {
        cert_manager_chart_version     = "1.14.2"
        cert_manager_email             = "your_email@gmail.com"
        cluster_issuer                 = "prod-issuer"
      }
      longhorn = {
        longhorn_chart_version         = "1.5.4"
        longhorn_nfs_storage           = "nfs://10.0.5.2:/mnt/HDD_POOL/k8s/z1-k8s/longhorn/"
        longhorn_domain_name           = "longhorn-z1.your_domain.com"
        longhorn_tls_secret_name       = "longhorn-z1-your_domain.com-tls"
      }
      ingress_nginx = {
        ingress_nginx_chart_version    = "4.10.0"
        nginx_controller_external_ip   = "10.0.5.200"
        nginx_controller_internal_ip   = "10.0.5.201"
      }
      kube_prometheus_stack = {
        kube_prometheus_stack_version  = "57.0.1"
        grafana_domain_name            = "grafana-z1.your_domain.com"
        grafana_tls_secret_name        = "grafana-z1-your_domain.com-tls"
        prometheus_domain_name         = "prometheus-z1.your_domain.com"
        prometheus_tls_secret_name     = "prometheus-z1-your_domain.com-tls"
        alert_manager_domain_name      = "alert-manager-z1.your_domain.com"
        alert_manager_tls_secret_name  = "alert-manager-z1-your_domain.com-tls"
        alert_manager_slack_channel    = "z1-alerts"
      }
      kube_dashboard = {
        kube_dashboard_user            = "your_username"
        kube_dashboard_version         = "2.7.0"
        kube_dashboard_domain_name     = "kubernetes-dashboard-z1.your_domain.com"
        kube_dashboard_tls_secret_name = "kubernetes-dashboard-z1-your_domain.com-tls"
      }
      newrelic = {
        newrelic_low_data_mode         = "true"
        newrelic_scrape_system_prom    = "true"
        newrelic_ksm_image_tag         = "2.10.0"
        newrelic_namespace             = "newrelic"
      }
      node_classes = {
        apiserver = {
          count      = 3
          cores      = 2
          sockets    = 2
          memory     = 4092
          disk_size  = 30
          start_ip   = 110
          labels = {
            "node_class" = "apiserver"
          }
        }
        etcd = {
          count      = 3
          cores      = 1
          sockets    = 2
          memory     = 2048
          disk_size  = 30
          start_ip   = 120
        }
        backup = {
          count      = 2
          cores      = 1
          sockets    = 2
          memory     = 2048
          disk_size  = 100
          start_ip   = 130
          labels = {
            "node_class" = "backup"
          }
        }
        db = {
          count      = 3
          cores      = 2
          sockets    = 2
          memory     = 8192
          disk_size  = 50
          start_ip   = 140
          labels = {
            "node_class" = "db"
          }
        }
        general = {
          count      = 5
          cores      = 4
          sockets    = 2
          memory     = 4192
          disk_size  = 100
          start_ip   = 150
          labels = {
            "node_class" = "general"
          }
        }
      }
    }
  }
}

