locals {
  ipv4_interface_list = join(",", flatten([
    for node in proxmox_virtual_environment_vm.node : [
      for ip in flatten([node.ipv4_addresses]) : ip
      if ip != "127.0.0.1"                         # Exclude loopback address
    ]
  ]))

  ipv6_interface_list = join(",", flatten([
    for node in proxmox_virtual_environment_vm.node : [
      for ip in flatten([node.ipv6_addresses]) : ip
      if ip != "::1" && !can(regex("^fe80:", ip))  # Exclude loopback and local-link addresses
    ]
  ]))
}

resource "proxmox_virtual_environment_firewall_options" "node" {
  depends_on = [ proxmox_virtual_environment_vm.node ]
  for_each = { for node in local.nodes : "${node.cluster_name}-${node.node_class}-${node.index}" => node }

  node_name = local.proxmox_node
  vm_id     = each.value.vm_id

  enabled       = local.cluster_config.networking.use_pve_firewall
  dhcp          = false
  ipfilter      = false
  log_level_in  = "nolog"
  log_level_out = "nolog"
  macfilter     = false
  ndp           = true
  input_policy  = "DROP"
  output_policy = "ACCEPT"
  radv          = false
}

# create aliasees for each node
resource "proxmox_virtual_environment_firewall_alias" "node_ipv4" {
  for_each = { for node in local.nodes : "${node.cluster_name}-${node.node_class}-${node.index}" => node if local.cluster_config.networking.use_pve_firewall }

  name    = "k8s-${each.key}-ipv4"
  cidr    = each.value.ipv4.vm_ip
  comment = "Managed by Terraform"
}
resource "proxmox_virtual_environment_firewall_alias" "node_ipv6" {
  for_each = { for node in local.nodes : "${node.cluster_name}-${node.node_class}-${node.index}" => node if local.cluster_config.networking.use_pve_firewall && local.cluster_config.networking.ipv6.enabled }

  name    = "k8s-${each.key}-ipv6"
  cidr    = each.value.ipv6.vm_ip
  comment = "Managed by Terraform"
}

# create aliases for each management ip
resource "proxmox_virtual_environment_firewall_alias" "management_ipv4" {
  for_each = { for i, cidr in local.management_cidrs_ipv4_list : "management-${i}-ipv4" => cidr if local.cluster_config.networking.use_pve_firewall }

  name    = each.key
  cidr    = each.value
  comment = "Managed by Terraform"
}
resource "proxmox_virtual_environment_firewall_alias" "management_ipv6" {
  for_each = { for i, cidr in local.management_cidrs_ipv6_list : "management-${i}-ipv6" => cidr if local.cluster_config.networking.use_pve_firewall && local.cluster_config.networking.ipv6.enabled }

  name    = each.key
  cidr    = each.value
  comment = "Managed by Terraform"
}

# create an alias for kube-vip
resource "proxmox_virtual_environment_firewall_alias" "kube_vip" {
  name    = "k8s-${local.cluster_config.cluster_name}-kube-vip"
  cidr    = local.cluster_config.networking.kube_vip.vip
  comment = "Managed by Terraform"
}

# group all k8s nodes
resource "proxmox_virtual_environment_firewall_ipset" "all_nodes_ipv4" {
  count = local.cluster_config.networking.use_pve_firewall ? 1 : 0
  depends_on = [
    proxmox_virtual_environment_firewall_alias.node_ipv4,
  ]

  name    = "k8s-${local.cluster_config.cluster_name}-all-nodes-ipv4"
  comment = "Managed by Terraform"

  dynamic "cidr" {
    for_each = { for key, node in local.nodes : "${node.cluster_name}-${node.node_class}-${node.index}" => node }
    content {
      name    = "dc/k8s-${cidr.key}-ipv4"
      comment = cidr.key
    }
  }
}

resource "proxmox_virtual_environment_firewall_ipset" "all_nodes_ipv6" {
  count = local.cluster_config.networking.use_pve_firewall && local.cluster_config.networking.ipv6.enabled ? 1 : 0
  depends_on = [
    proxmox_virtual_environment_firewall_alias.node_ipv6
  ]

  name    = "k8s-${local.cluster_config.cluster_name}-all-nodes-ipv6"
  comment = "Managed by Terraform"

  dynamic "cidr" {
    for_each = { for key, node in local.nodes : "${node.cluster_name}-${node.node_class}-${node.index}" => node if local.cluster_config.networking.ipv6.enabled }
    content {
      name    = "dc/k8s-${cidr.key}-ipv6"
      comment = cidr.key
    }
  }
}

# group all apiserver nodes
resource "proxmox_virtual_environment_firewall_ipset" "apiserver_nodes_ipv4" {
  count = local.cluster_config.networking.use_pve_firewall ? 1 : 0
  depends_on = [
    proxmox_virtual_environment_firewall_alias.node_ipv4
  ]

  name    = "k8s-${local.cluster_config.cluster_name}-apiserver-nodes-ipv4"
  comment = "Managed by Terraform"

  dynamic "cidr" {
    for_each = { for key, node in local.nodes : "${node.cluster_name}-${node.node_class}-${node.index}" => node if node.node_class == "apiserver" }
    content {
      name    = "dc/k8s-${cidr.key}-ipv4"
      comment = cidr.key
    }
  }
}
resource "proxmox_virtual_environment_firewall_ipset" "apiserver_nodes_ipv6" {
  count = local.cluster_config.networking.use_pve_firewall && local.cluster_config.networking.ipv6.enabled ? 1 : 0
  depends_on = [
    proxmox_virtual_environment_firewall_alias.node_ipv6
  ]

  name    = "k8s-${local.cluster_config.cluster_name}-apiserver-nodes-ipv6"
  comment = "Managed by Terraform"

  dynamic "cidr" {
    for_each = { for key, node in local.nodes : "${node.cluster_name}-${node.node_class}-${node.index}" => node if node.node_class == "apiserver" && local.cluster_config.networking.ipv6.enabled }
    content {
      name    = "dc/k8s-${cidr.key}-ipv6"
      comment = cidr.key
    }
  }
}

# group all management ips
resource "proxmox_virtual_environment_firewall_ipset" "management_ipv4" {
  count = local.cluster_config.networking.use_pve_firewall ? 1 : 0
  depends_on = [
    proxmox_virtual_environment_firewall_alias.management_ipv4
  ]

  name    = "k8s-${local.cluster_config.cluster_name}-management-ipv4"
  comment = "Managed by Terraform"

  dynamic "cidr" {
    for_each = { for i, cidr in local.management_cidrs_ipv4_list : "management-${i}-ipv4" => cidr if local.cluster_config.networking.use_pve_firewall }
    content {
      name    = "dc/${cidr.key}"
      comment = cidr.key
    }
  }
}
resource "proxmox_virtual_environment_firewall_ipset" "management_ipv6" {
  count = local.cluster_config.networking.use_pve_firewall && local.cluster_config.networking.ipv6.enabled ? 1 : 0
  depends_on = [
    proxmox_virtual_environment_firewall_alias.management_ipv6
  ]

  name    = "k8s-${local.cluster_config.cluster_name}-management-ipv6"
  comment = "Managed by Terraform"

  dynamic "cidr" {
    for_each = { for i, cidr in local.management_cidrs_ipv6_list : "management-${i}-ipv6" => cidr if local.cluster_config.networking.use_pve_firewall && local.cluster_config.networking.ipv6.enabled }
    content {
      name    = "dc/${cidr.key}"
      comment = cidr.key
    }
  }
}

# alias for kube-vip
resource "proxmox_virtual_environment_firewall_ipset" "kube_vip" {
  count = local.cluster_config.networking.use_pve_firewall ? 1 : 0
  depends_on = [
    proxmox_virtual_environment_firewall_alias.kube_vip
  ]

  name    = "k8s-${local.cluster_config.cluster_name}-kube-vip"
  comment = "Managed by Terraform"

  cidr {
    name    = "dc/${proxmox_virtual_environment_firewall_alias.kube_vip.name}"
    comment = proxmox_virtual_environment_firewall_alias.kube_vip.name
  }
}

# group all etcd nodes
resource "proxmox_virtual_environment_firewall_ipset" "etcd_nodes_ipv4" {
  count = local.cluster_config.networking.use_pve_firewall ? 1 : 0
  depends_on = [
    proxmox_virtual_environment_firewall_alias.node_ipv4
  ]

  name    = "k8s-${local.cluster_config.cluster_name}-etcd-nodes-ipv4"
  comment = "Managed by Terraform"

  dynamic "cidr" {
    for_each = { for key, node in local.nodes : "${node.cluster_name}-${node.node_class}-${node.index}" => node if node.node_class == "etcd" }
    content {
      name    = "dc/k8s-${cidr.key}-ipv4"
      comment = cidr.key
    }
  }
}
resource "proxmox_virtual_environment_firewall_ipset" "etcd_nodes_ipv6" {
  count = local.cluster_config.networking.use_pve_firewall && local.cluster_config.networking.ipv6.enabled ? 1 : 0
  depends_on = [
    proxmox_virtual_environment_firewall_alias.node_ipv6
  ]

  name    = "k8s-${local.cluster_config.cluster_name}-etcd-nodes-ipv6"
  comment = "Managed by Terraform"

  dynamic "cidr" {
    for_each = { for key, node in local.nodes : "${node.cluster_name}-${node.node_class}-${node.index}" => node if node.node_class == "etcd" && local.cluster_config.networking.ipv6.enabled }
    content {
      name    = "dc/k8s-${cidr.key}-ipv6"
      comment = cidr.key
    }
  }
}

# group all worker nodes
resource "proxmox_virtual_environment_firewall_ipset" "worker_nodes_ipv4" {
  count = local.cluster_config.networking.use_pve_firewall ? 1 : 0
  depends_on = [
    proxmox_virtual_environment_firewall_alias.node_ipv4
  ]

  name    = "k8s-${local.cluster_config.cluster_name}-worker-nodes-ipv4"
  comment = "Managed by Terraform"

  dynamic "cidr" {
    for_each = { for key, node in local.nodes : "${node.cluster_name}-${node.node_class}-${node.index}" => node if node.node_class != "apiserver" && node.node_class != "etcd" }
    content {
      name    = "dc/k8s-${cidr.key}-ipv4"
      comment = cidr.key
    }
  }
}
resource "proxmox_virtual_environment_firewall_ipset" "worker_nodes_ipv6" {
  count = local.cluster_config.networking.use_pve_firewall && local.cluster_config.networking.ipv6.enabled ? 1 : 0
  depends_on = [
    proxmox_virtual_environment_firewall_alias.node_ipv6
  ]

  name    = "k8s-${local.cluster_config.cluster_name}-worker-nodes-ipv6"
  comment = "Managed by Terraform"

  dynamic "cidr" {
    for_each = { for key, node in local.nodes : "${node.cluster_name}-${node.node_class}-${node.index}" => node if node.node_class != "apiserver" && node.node_class != "etcd" && local.cluster_config.networking.ipv6.enabled }
    content {
      name    = "dc/k8s-${cidr.key}-ipv6"
      comment = cidr.key
    }
  }
}

# allow k8s api
resource "proxmox_virtual_environment_cluster_firewall_security_group" "k8s_api" {
  count = local.cluster_config.networking.use_pve_firewall ? 1 : 0

  name    = "k8s-${local.cluster_config.cluster_name}-api"
  comment = "K8s API for ${local.cluster_config.cluster_name} cluster"

  rule {
      type    = "in"
      action  = "ACCEPT"
      comment = "Allow K8s API from Management IP or Range IPV4"
      source  = "+${proxmox_virtual_environment_firewall_ipset.management_ipv4[0].name}"
      dest    = "+${proxmox_virtual_environment_firewall_ipset.apiserver_nodes_ipv4[0].name}"
      dport   = "6443"
      proto   = "tcp"
      log     = "info"
  }
  dynamic "rule" {
    for_each = local.cluster_config.networking.ipv6.enabled ? [1] : []
    content {
      type    = "in"
      action  = "ACCEPT"
      comment = "Allow K8s API from Management IP or Range IPV6"
      source  = "+${proxmox_virtual_environment_firewall_ipset.management_ipv6[0].name}"
      dest    = "+${proxmox_virtual_environment_firewall_ipset.apiserver_nodes_ipv6[0].name}"
      dport   = "6443"
      proto   = "tcp"
      log     = "info"
    }
  }
  rule {
      type    = "in"
      action  = "ACCEPT"
      comment = "Allow K8s API from Management IP or Range IPv4 VIP"
      source  = "+${proxmox_virtual_environment_firewall_ipset.management_ipv4[0].name}"
      dest    = "+${proxmox_virtual_environment_firewall_ipset.kube_vip[0].name}"
      dport   = "6443"
      proto   = "tcp"
      log     = "info"
  }
  dynamic "rule" {
    for_each = local.cluster_config.networking.ipv6.enabled ? [1] : []
    content {
      type     = "in"
      action   = "ACCEPT"
      comment  = "Allow K8s API from Management IP or Range IPv6 VIP"
      source   = "+${proxmox_virtual_environment_firewall_ipset.management_ipv6[0].name}"
      dest     = "+${proxmox_virtual_environment_firewall_ipset.kube_vip[0].name}"
      dport    = "6443"
      proto    = "tcp"
      log      = "info"
    }
  }
  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Allow K8s API from all K8s Nodes IPV4"
    source  = "+${proxmox_virtual_environment_firewall_ipset.all_nodes_ipv4[0].name}"
    dest    = "+${proxmox_virtual_environment_firewall_ipset.apiserver_nodes_ipv4[0].name}"
    dport   = "6443"
    proto   = "tcp"
    log     = "nolog"
  }
  dynamic "rule" {
    for_each = local.cluster_config.networking.ipv6.enabled ? [1] : []
    content {
      type    = "in"
      action  = "ACCEPT"
      comment = "Allow K8s API from all K8s Nodes IPV6"
      source  = "+${proxmox_virtual_environment_firewall_ipset.all_nodes_ipv6[0].name}"
      dest    = "+${proxmox_virtual_environment_firewall_ipset.apiserver_nodes_ipv6[0].name}"
      dport   = "6443"
      proto   = "tcp"
      log     = "nolog"
    }
  }
  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Allow K8s API from all K8s Nodes VIP"
    source  = local.cluster_config.networking.kube_vip.use_ipv6 ? "+${proxmox_virtual_environment_firewall_ipset.all_nodes_ipv6[0].name}" : "+${proxmox_virtual_environment_firewall_ipset.all_nodes_ipv4[0].name}"
    dest    = "+${proxmox_virtual_environment_firewall_ipset.kube_vip[0].name}"
    dport   = "6443"
    proto   = "tcp"
    log     = "nolog"
  }
  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Allow K8s API from all K8s Nodes QEMU-found IPs"
    source  = local.cluster_config.networking.kube_vip.use_ipv6 ? local.ipv6_interface_list : local.ipv4_interface_list
    dest    = "+${proxmox_virtual_environment_firewall_ipset.kube_vip[0].name}"
    dport   = "6443"
    proto   = "tcp"
    log     = "nolog"
  }
}

# allow admin ssh
resource "proxmox_virtual_environment_cluster_firewall_security_group" "ssh" {
  count = local.cluster_config.networking.use_pve_firewall ? 1 : 0

  name    = "k8s-${local.cluster_config.cluster_name}-ssh"
  comment = "SSH into ${local.cluster_config.cluster_name} cluster"

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Allow SSH from Management IP or Range IPv4"
    source  = "+${proxmox_virtual_environment_firewall_ipset.management_ipv4[0].name}"
    dest    = "+${proxmox_virtual_environment_firewall_ipset.all_nodes_ipv4[0].name}"
    dport   = "22"
    proto   = "tcp"
    log     = "info"
  }
  dynamic "rule" {
    for_each = local.cluster_config.networking.ipv6.enabled ? [1] : []
    content {
      type    = "in"
      action  = "ACCEPT"
      comment = "Allow SSH from Management IP or Range IPv6"
      source  = "+${proxmox_virtual_environment_firewall_ipset.management_ipv6[0].name}"
      dest    = "+${proxmox_virtual_environment_firewall_ipset.all_nodes_ipv6[0].name}"
      dport   = "22"
      proto   = "tcp"
      log     = "info"
    }
  }
}

# allow admin ping
resource "proxmox_virtual_environment_cluster_firewall_security_group" "ping" {
  count = local.cluster_config.networking.use_pve_firewall ? 1 : 0

  name    = "k8s-${local.cluster_config.cluster_name}-ping"
  comment = "Ping nodes in ${local.cluster_config.cluster_name} cluster"

  # For each range or IP in the management_ranges
  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Allow Ping from Management IP or Range IPv4"
    source  = "+${proxmox_virtual_environment_firewall_ipset.management_ipv4[0].name}"
    dest    = "+${proxmox_virtual_environment_firewall_ipset.all_nodes_ipv4[0].name}"
    macro   = "Ping"
    log     = "info"
  }
  dynamic "rule" {
    for_each = local.cluster_config.networking.ipv6.enabled ? [1] : []
    content {
      type    = "in"
      action  = "ACCEPT"
      comment = "Allow Ping from Management IP or Range IPv6"
      source  = "+${proxmox_virtual_environment_firewall_ipset.management_ipv6[0].name}"
      dest    = "+${proxmox_virtual_environment_firewall_ipset.all_nodes_ipv6[0].name}"
      macro   = "Ping"
      log     = "info"
    }
  }
  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Allow Ping from Management IP or Range VIP"
    source  = local.cluster_config.networking.kube_vip.use_ipv6 ? "+${proxmox_virtual_environment_firewall_ipset.management_ipv6[0].name}":  "+${proxmox_virtual_environment_firewall_ipset.management_ipv4[0].name}"
    dest    = "+${proxmox_virtual_environment_firewall_ipset.kube_vip[0].name}"
    macro   = "Ping"
    log     = "info"
  }
}

# allow etcd
resource "proxmox_virtual_environment_cluster_firewall_security_group" "etcd" {
  count = local.cluster_config.networking.use_pve_firewall && try(local.cluster_config.node_classes.etcd, null) != null ? 1 : 0

  name    = "k8s-${local.cluster_config.cluster_name}-etcd"
  comment = "Etcd for ${local.cluster_config.cluster_name} cluster"

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Allow Etcd IPv4"
    source  = "+${proxmox_virtual_environment_firewall_ipset.apiserver_nodes_ipv4[0].name}"
    dest    = local.cluster_config.node_classes.etcd.count == 0 ? "+${proxmox_virtual_environment_firewall_ipset.apiserver_nodes_ipv4[0].name}" : "+${proxmox_virtual_environment_firewall_ipset.etcd_nodes_ipv4[0].name}"
    dport   = "2379:2380"
    proto   = "tcp"
    log     = "nolog"
  }
  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Allow Etcd IPv6"
    source  = "+${proxmox_virtual_environment_firewall_ipset.apiserver_nodes_ipv6[0].name}"
    dest    = local.cluster_config.node_classes.etcd.count == 0 ? "+${proxmox_virtual_environment_firewall_ipset.apiserver_nodes_ipv6[0].name}" : "+${proxmox_virtual_environment_firewall_ipset.etcd_nodes_ipv6[0].name}"
    dport   = "2379:2380"
    proto   = "tcp"
    log     = "nolog"
  }
}

# allow kubelet api (control-plane)
resource "proxmox_virtual_environment_cluster_firewall_security_group" "kubelet_api_apiserver" {
  count = local.cluster_config.networking.use_pve_firewall ? 1 : 0

  name    = "k8s-${local.cluster_config.cluster_name}-kt-cp"
  comment = "Kubelet API for ${local.cluster_config.cluster_name} cluster apiservers"

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Allow Kubelet API IPv4"
    source  = "+${proxmox_virtual_environment_firewall_ipset.apiserver_nodes_ipv4[0].name}"
    dest    = "+${proxmox_virtual_environment_firewall_ipset.apiserver_nodes_ipv4[0].name}"
    dport   = "10250"
    proto   = "tcp"
    log     = "nolog"
  }
  dynamic "rule" {
    for_each = local.cluster_config.networking.ipv6.enabled ? [1] : []
    content {
      type    = "in"
      action  = "ACCEPT"
      comment = "Allow Kubelet API IPv6"
      source  = "+${proxmox_virtual_environment_firewall_ipset.apiserver_nodes_ipv6[0].name}"
      dest    = "+${proxmox_virtual_environment_firewall_ipset.apiserver_nodes_ipv6[0].name}"
      dport   = "10250"
      proto   = "tcp"
      log     = "nolog"
    }
  }
}

# allow kubelet api (worker)
resource "proxmox_virtual_environment_cluster_firewall_security_group" "kubelet_api_worker" {
  count = local.cluster_config.networking.use_pve_firewall ? 1 : 0

  name    = "k8s-${local.cluster_config.cluster_name}-kt-wk"
  comment = "Kubelet API for ${local.cluster_config.cluster_name} cluster workers"

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Allow Kubelet API IPv4"
    source  = "+${proxmox_virtual_environment_firewall_ipset.apiserver_nodes_ipv4[0].name}"
    dest    = "+${proxmox_virtual_environment_firewall_ipset.worker_nodes_ipv4[0].name}"
    dport   = "10250"
    proto   = "tcp"
    log     = "nolog"
  }
  dynamic "rule" {
    for_each = local.cluster_config.networking.ipv6.enabled ? [1] : []
    content {
      type    = "in"
      action  = "ACCEPT"
      comment = "Allow Kubelet API IPv6"
      source  = "+${proxmox_virtual_environment_firewall_ipset.apiserver_nodes_ipv6[0].name}"
      dest    = "+${proxmox_virtual_environment_firewall_ipset.worker_nodes_ipv6[0].name}"
      dport   = "10250"
      proto   = "tcp"
      log     = "nolog"
    }
  }
}

# allow metrics-server port
resource "proxmox_virtual_environment_cluster_firewall_security_group" "metrics_server" {
  count = local.cluster_config.networking.use_pve_firewall ? 1 : 0

  name    = "k8s-${local.cluster_config.cluster_name}-metrics"
  comment = "Metrics-Server in ${local.cluster_config.cluster_name} cluster"

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Allow Metrics Server Port IPv4"
    source  = "+${proxmox_virtual_environment_firewall_ipset.all_nodes_ipv4[0].name}"
    dest    = "+${proxmox_virtual_environment_firewall_ipset.all_nodes_ipv4[0].name}"
    dport   = "10250"
    proto   = "tcp"
    log     = "nolog"
  }
  dynamic "rule" {
    for_each = local.cluster_config.networking.ipv6.enabled ? [1] : []
    content {
      type    = "in"
      action  = "ACCEPT"
      comment = "Allow Metrics Server Port IPv6"
      source  = "+${proxmox_virtual_environment_firewall_ipset.all_nodes_ipv6[0].name}"
      dest    = "+${proxmox_virtual_environment_firewall_ipset.all_nodes_ipv6[0].name}"
      dport   = "10250"
      proto   = "tcp"
      log     = "nolog"
    }
  }
}

# allow cilium ports
resource "proxmox_virtual_environment_cluster_firewall_security_group" "cilium" {
  count = local.cluster_config.networking.use_pve_firewall ? 1 : 0

  name    = "k8s-${local.cluster_config.cluster_name}-cilium"
  comment = "Cilium in ${local.cluster_config.cluster_name} cluster"

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Allow Cilium TCP Ports IPv4 Part 1"
    source  = "+${proxmox_virtual_environment_firewall_ipset.all_nodes_ipv4[0].name}"
    dest    = "+${proxmox_virtual_environment_firewall_ipset.all_nodes_ipv4[0].name}"
    dport   = "4240,4244,4245,4250,4251,6060,6061,6062,9878"
    proto   = "tcp"
    log     = "nolog"
  }
  dynamic "rule" {
    for_each = local.cluster_config.networking.ipv6.enabled ? [1] : []
    content {
      type    = "in"
      action  = "ACCEPT"
      comment = "Allow Cilium TCP Ports IPv6 Part 1"
      source  = "+${proxmox_virtual_environment_firewall_ipset.all_nodes_ipv6[0].name}"
      dest    = "+${proxmox_virtual_environment_firewall_ipset.all_nodes_ipv6[0].name}"
      dport   = "4240,4244,4245,4250,4251,6060,6061,6062,9878"
      proto   = "tcp"
      log     = "nolog"
    }
  }
  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Allow Cilium TCP Ports IPv4 Part 2"
    source  = "+${proxmox_virtual_environment_firewall_ipset.all_nodes_ipv4[0].name}"
    dest    = "+${proxmox_virtual_environment_firewall_ipset.all_nodes_ipv4[0].name}"
    dport   = "9879,9890,9891,9893,9901,9962,9963,9964"
    proto   = "tcp"
    log     = "nolog"
  }
  dynamic "rule" {
    for_each = local.cluster_config.networking.ipv6.enabled ? [1] : []
    content {
      type    = "in"
      action  = "ACCEPT"
      comment = "Allow Cilium TCP Ports IPv6 Part 2"
      source  = "+${proxmox_virtual_environment_firewall_ipset.all_nodes_ipv6[0].name}"
      dest    = "+${proxmox_virtual_environment_firewall_ipset.all_nodes_ipv6[0].name}"
      dport   = "9879,9890,9891,9893,9901,9962,9963,9964"
      proto   = "tcp"
      log     = "nolog"
    }
  }
  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Allow Cilium UDP Ports IPv4"
    source  = "+${proxmox_virtual_environment_firewall_ipset.all_nodes_ipv4[0].name}"
    dest    = "+${proxmox_virtual_environment_firewall_ipset.all_nodes_ipv4[0].name}"
    dport   = "51871,8472,6081,8472"
    proto   = "udp"
    log     = "nolog"
  }
  dynamic "rule" {
    for_each = local.cluster_config.networking.ipv6.enabled ? [1] : []
    content {
      type    = "in"
      action  = "ACCEPT"
      comment = "Allow Cilium UDP Ports IPv6"
      source  = "+${proxmox_virtual_environment_firewall_ipset.all_nodes_ipv6[0].name}"
      dest    = "+${proxmox_virtual_environment_firewall_ipset.all_nodes_ipv6[0].name}"
      dport   = "51871,8472,6081,8472"
      proto   = "udp"
      log     = "nolog"
    }
  }
}

# allow NodePort services
resource "proxmox_virtual_environment_cluster_firewall_security_group" "nodeport" {
  count = local.cluster_config.networking.use_pve_firewall ? 1 : 0

  name    = "k8s-${local.cluster_config.cluster_name}-np"
  comment = "NodePorts for ${local.cluster_config.cluster_name} cluster"

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Allow NodePort Services IPv4"
    source  = "+${proxmox_virtual_environment_firewall_ipset.all_nodes_ipv4[0].name}"
    dest    = "+${proxmox_virtual_environment_firewall_ipset.worker_nodes_ipv4[0].name}"
    dport   = "30000:32767"
    proto   = "tcp"
    log     = "nolog"
  }
  dynamic "rule" {
    for_each = local.cluster_config.networking.ipv6.enabled ? [1] : []
    content {
      type    = "in"
      action  = "ACCEPT"
      comment = "Allow NodePort Services IPv6"
      source  = "+${proxmox_virtual_environment_firewall_ipset.all_nodes_ipv6[0].name}"
      dest    = "+${proxmox_virtual_environment_firewall_ipset.worker_nodes_ipv6[0].name}"
      dport   = "30000:32767"
      proto   = "tcp"
      log     = "nolog"
    }
  }
}

# activate all security groups on the VMs
resource "proxmox_virtual_environment_firewall_rules" "main" {
  depends_on = [
    proxmox_virtual_environment_vm.node,
    proxmox_virtual_environment_cluster_firewall_security_group.k8s_api,
    proxmox_virtual_environment_cluster_firewall_security_group.ssh,
    proxmox_virtual_environment_cluster_firewall_security_group.ping,
    proxmox_virtual_environment_cluster_firewall_security_group.etcd,
    proxmox_virtual_environment_cluster_firewall_security_group.kubelet_api_apiserver,
    proxmox_virtual_environment_cluster_firewall_security_group.kubelet_api_worker,
    proxmox_virtual_environment_cluster_firewall_security_group.metrics_server,
    proxmox_virtual_environment_cluster_firewall_security_group.cilium,
    proxmox_virtual_environment_cluster_firewall_security_group.nodeport,
  ]
  for_each = { for node in local.nodes : "${node.cluster_name}-${node.node_class}-${node.index}" => node if local.cluster_config.networking.use_pve_firewall }

  node_name = local.proxmox_node
  vm_id     = each.value.vm_id

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.k8s_api[0].name
    comment        = proxmox_virtual_environment_cluster_firewall_security_group.k8s_api[0].name
    iface          = "net0"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.ssh[0].name
    comment        = proxmox_virtual_environment_cluster_firewall_security_group.ssh[0].name
    iface          = "net0"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.ping[0].name
    comment        = proxmox_virtual_environment_cluster_firewall_security_group.ping[0].name
    iface          = "net0"
  }

  dynamic "rule" {
    for_each = local.cluster_config.networking.use_pve_firewall && try(local.cluster_config.node_classes.etcd, null) != null ? [1] : []

    content {
      security_group = proxmox_virtual_environment_cluster_firewall_security_group.etcd[0].name
      comment        = proxmox_virtual_environment_cluster_firewall_security_group.etcd[0].name
      iface          = "net0"
    }
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.kubelet_api_apiserver[0].name
    comment        = proxmox_virtual_environment_cluster_firewall_security_group.kubelet_api_apiserver[0].name
    iface          = "net0"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.kubelet_api_worker[0].name
    comment        = proxmox_virtual_environment_cluster_firewall_security_group.kubelet_api_worker[0].name
    iface          = "net0"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.metrics_server[0].name
    comment        = proxmox_virtual_environment_cluster_firewall_security_group.metrics_server[0].name
    iface          = "net0"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.cilium[0].name
    comment        = proxmox_virtual_environment_cluster_firewall_security_group.cilium[0].name
    iface          = "net0"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.nodeport[0].name
    comment        = proxmox_virtual_environment_cluster_firewall_security_group.nodeport[0].name
    iface          = "net0"
  }
}