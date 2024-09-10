# ClusterCreator - Terraform & Ansible K8S Bootstrapping on Proxmox
![alpha, beta, and gamma Example Clusters](https://github.com/christensenjairus/ClusterCreator/assets/58751387/7193a4ad-b3d9-4b90-98f3-e60fde571412)

## Automate the creation of fully functional K8S clusters of any size on Proxmox

This project will assist you in automating bootstrapping k8s clusters on Proxmox, optionally with a dedicated Unifi network and VLAN, as well as maintaining that cluster.

Having a virtualized k8s cluster allows you to not only simulate a cloud environment, but scale and customize your cluster to your needs, adding/removing nodes and disks, managing disk backups and snapshots, customizing node class types, and controlling state.

Terraform/OpenTofu & Ansible automate to create even more complex setups, like using a decoupled etcd cluster or using a large number of worker nodes with differing cpu/mem/disk/networking/labels. OpenTofu creates the VMs and VLANs, and Ansible installs Kubernetes as well as various add-ons for networking, metrics, and storage.

See a demo of how it works step by step [on my blog](https://cyber-engine.com/blog/2024/06/25/k8s-on-proxmox-using-clustercreator/).

##### The `create_template.sh` script will create a cloud-init ready virtual machine template for Tofu to use.
* Installs apt packages kubeadm, kubelet, kubectl, helm, containerd, nfs tools, iscsi-tools, qemu-guest-agent, mysql-client, ceph, etc.
* Installs packages from source like the cilium cli, hubble cli, cni plugins, etcdctl, vtctldclient, and vtexplain
* Updates to operating system
* Adds various necessary system configurations for k8s, like kernel modules and sysctl settings
* Adds multipath configuration, which is important for storage systems like Longhorn.
* Supports both Ubuntu and Debian images

##### The Tofu cluster configuration allows
* Optional decoupled etcd cluster
* Optional dual stack networking
* Proxmox pool configuration
* Custom network & vlan Unifi configuration (optional)
* Custom worker classes (general, database, and storage are included, but you can add more)
* Custom quantities of control-plane, etcd, and custom worker nodes
* Custom hardware requirements for each node class
* Custom disk configurations
* Custom node IPs
* Custom proxmox tags

##### `./install_k8s.sh` runs a series of Ansible playbooks to create a fresh, minimal cluster. The Ansible playbooks include configuration and installation of
* Decoupled ETCD cluster (optional)
* Highly available control plane using Kube-VIP
* Cilium CNI (replacing kube-router, providing full eBPF. Optional dual stack networking)
* Metrics server
* Node labels
* Node taints
* Auto-Provisioning Local StorageClass (rancher) (set as default StorageClass)
* Non-Auto-Provisioning Local StorageClass (k8s built-in)
* Prepares, updates, reboots, and joins new nodes to an existing cluster with the `--add-nodes` flag, allowing you to grow your cluster as needed.

# Usage
Before using this project, see the [section on configuring your secrets files](#configuring-secrets-files).

### Create a cloud-init ready virtual machine template for Tofu to use
```bash
./create_template.sh
```
This will ssh into proxmox and create you a cloud-init ready template. This template is based on the files found in `k8s_vm_template`, `.env`, and `k8s.env`. The vm that is created will start for few minutes install all the necessary packages, then will reset the cloud-init configuration and shut down. The packages installed include containerd, runc, kubeadm, kubelet, kubectl, etcdctl, cilium cli, hubble cli, helm, and other necessary system packages.

### Initialize Tofu
```bash
tofu init
```
This only has to be done once to initialize the tofu modules.

### Create your cluster's Tofu workspace
```bash
tofu workspace new <cluster_name>
```
This will ensure that your tofu commands only work on the cluster of your choosing. The Tofu configuration relies on the workspace name to know which cluster you'll be working with. You can later use `tofu workspace switch <cluster_name>` to switch between clusters.

### Create the VMs with Tofu
```bash
tofu apply [--auto-approve] [-var="template_vm_id=<vm_id>"] [-var="proxmox_node=<node_name>"]
``` 
This will clone the template using tofu and set cloud-init parameters, as well as create a pool in proxmox, create a VLAN in Unifi, and create the cluster specifications file `ansible/tmp/<cluster_name>/cluster_config.json`. The cluster config file tells Ansible how the cluster should be configured. Default template_vm_id is 9000. 

### Install K8S with Ansible
```bash
./install_k8s.sh --cluster_name <CLUSTER_NAME> [-a/--add-nodes]
```
This will run a series of Ansible playbooks to create a fresh, minimal cluster. This is independent of the Tofu workspace and uses the `cluster_config.json` file and creates its own `ansible-hosts.txt` file based on the cluster configuration.

The `--add-nodes` flag will prepare and add **new** nodes to an already initialized cluster. This works for both control-plane and worker nodes.

*Note: Do not use the `--add-nodes` to set up or edit a decoupled etcd cluster. That must be done upon initialization. But it will work for editing control plane nodes that reference the decoupled etcd cluster.*

### Drain or remove a node from the cluster
```bash
./remove_node.sh -n/--cluster-name <CLUSTER_NAME> -h/--hostname <NODE_HOSTNAME> -t/--timeout <TIMEOUT_SECONDS> [-d/--delete]
```
This will remove a worker or control plane node from the cluster and optionally delete & reset it. This includes removing etcd membership if the node is a stacked etcd control-plane node as well as untaints the control plane nodes when the last worker node is removed. 

The `--delete` flag will not only delete the node from the cluster, but will run the `./uninstall_k8s.sh` script to ensure that it is completely ready to start fresh when recomissioned. 

This does not work for decoupled etcd nodes.

### Uninstall K8S with Ansible
```bash
./uninstall_k8s.sh -n/--cluster_name <CLUSTER_NAME> [-h/--single-hostname <HOSTNAME_TO_RESET>]
```
This will run an Ansible playbook to reset k8s. Without the `--single-hostname` flag, all nodes will be reset and the cluster will be deleted.

### Destroy the VMs with Tofu
```bash
tofu destroy [--auto-approve]
```
This will remove the VMs, Pool, and VLAN.

### Power on/off your cluster
```bash
./powerctl_pool.sh [--start|--shutdown|--pause|--resume|--hibernate|--stop] <POOL_NAME> [--timeout <timeout_in_seconds>]
```
This will perform QEMU power control functions for the VMs in the specified pool. The timeout is optional, only applied for start/stop/shutdown, and defaults to 600 seconds. Pools are in all-caps. Requires the qemu-guest-agent to be running in the VM.

### Run bash commands on ansible host groups
```bash
./run_command_on_host_group.sh [-n/--cluster-name <CLUSTER_NAME> [-g/--group <GROUP_NAME>] [-c/--command '<command>']
```
This will run bash commands on the ansible host group you define. 'all' is the default group name. Multiple groups can be chained together with a comma and surrounding quotations.

# Dynamic configurations
The dynamic nature of OpenTofu + Ansible allows the following
* 1 - ∞ control plane nodes
* 0 - ∞ etcd nodes
* 0 - ∞ worker nodes of different classes. The 'classes' are defined by name, cpu, memory, and disk requirements.

# Included Examples

### Simplest cluster possible - single node, much like the defaults for minikube or kind

* `alpha` cluster (single node cluster)
  * 1 control plane node
    * 16 cores, 16GB RAM, 100GB disk

*Note: Having less than 1 worker node will make Ansible untaint the control plane node(s), allowing it to run workloads.*

### Add worker nodes of varying types for different workload needs

* `beta` cluster
  * 1 control plane node
    * 4 cores, 4GB RAM, 30GB disk
  * 1 worker node of class `storage`
    * 2 cores, 2GB RAM, 100GB disk
  * 1 worker node of class `database`
    * 4 cores, 8GB RAM, 50GB disk
  * 1 worker node of class `general`
    * 8 cores, 4GB RAM, 30GB disk

*Note: etcd nodes are not shown in cluster, but they are used by the control plane nodes.*

### Make the control plane highly available. Add an decoupled etcd cluster. Add more custom workers

* `gamma` cluster
  * 3 control plane nodes
    * 4 cores, 4GB RAM, 30GB disk
  * 3 decoupled etcd nodes
    * 2 cores, 2GB RAM, 30GB disk
  * 3 worker nodes of class `storage`
    * 2 cores, 2GB RAM, 30GB os disk, 100GB extra disk (for a future ceph cluster)
  * 3 worker nodes of class `database`
    * 4 cores, 8GB RAM, 50GB disk
  * 5 worker nodes of class `general`
    * 8 cores, 4GB RAM, 30GB os disk

### Add your own worker types for more flexible node configurations

* Theoretical overkill cluster
  * 9 control plane nodes
  * 7 decoupled etcd nodes
  * 5 worker nodes of class `storage`
  * 15 worker nodes of class `database`
  * 20 worker nodes of class `general`
  * 5 worker nodes of class `sandbox` # possible new class
  * 5 worker nodes of class `fedramp` # possible new class
  * 5 worker nodes of class `backup` # possible new class

# Configuring Secrets Files
Create the following two files.

### For Tofu
See [here](https://registry.terraform.io/providers/bpg/proxmox/latest/docs#api-token-authentication) for info on how to get a proxmox user and api token set up for this.
#### `secrets.tf`
Placed in topmost directory
```tf
variable "vm_username" {
    default = "line6" # change me to your username
}
variable "vm_password" {
    default = "<password here>"
}
variable "vm_ssh_key" {
    default = "ssh-rsa <key_here>"
}
variable "proxmox_username" {
    default = "tofu"
}
variable "proxmox_api_token" {
    default = "tofu@pve!<token_name>=<token>"
}
variable "unifi_username" {
    default = "tofu"
}
variable "unifi_password" {
    default = "<tofu_unifi_password>"
}
```
For the proxmox api token, you'll want to create a new user for tofu with only the required permissions and use a token for authentication.
* In a shell on the proxmox host, run
  ```bash
  pveum role add tofu -privs "Datastore.AllocateSpace Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.Monitor VM.PowerMgmt SDN.Use Pool.Audit"
  pveum user add tofu@pve --password <password> # this password doesn't need to be saved anywhere, we'll use token auth instead
  pveum aclmod / -user tofu@pve -role tofu
  ```
* Next, log into the Proxmox Console and go to Datacenter -> Permissions -> Api Tokens -> Add API Token.
* Select the `tofu@pve` user and give the token a name.
* Uncheck 'Privilege Separation'.
* Click 'Add'
* Copy the token and paste it into the `secrets.tf` file using the token name you specify upon creation.

For the Unifi password, you'll want to create a new service account user for tofu.
* In the Unifi Controller, go to Settings -> Admins & Users.
* Add a role called `Network_Service_Account` with only the `Site Admin` permissions the Network app.
* Create a new user named `tofu`. Restrict the user to local access only. Set the user's role to be `Network_Service_Account`.
* Use the new user password into `secrets.tf` as the unifi password.

### For bash
#### `.env`
Placed in topmost directory.
```bash
# Secrets for ./create_template.sh and ./install_k8s.sh
VM_USERNAME="<username_here>"  # username for all k8s_vm_template VMs managed by tofu
VM_PASSWORD="<password_here>"  # user password for all k8s_vm_template VMs managed by tofu
```

## Other files that need editing
The other configuration files, listed below, need to be looked through and tweaked to your needs.
* `k8s.env` holds versions of k8s and other software as well as the template vm configuration.
* `vars.tf` holds non-sensitive info for tofu.
* `clusters.tf` holds the cluster configurations. Make sure to change the username in this file to your own username.
* `main.tf` holds vm/vlan/pool tofu resources.

## Installation Errors
`tofu apply` may exit with errors because it is difficult for Proxmox to clone the same template over and over. You may need to run `tofu apply` a few times with larger clusters because of this. Proxmox may also need help if it says that configs already exist or if a VM is not responding.

A workaround is to add nodes to your cluster in batches and run `tofu apply` to create smaller sets of nodes. You may want to do this anyway so you can distribute the VMs across your proxmox cluster and vary the `proxmox_node` argument.

If you do need to undo the k8s install on the VMs `./uninstall_k8s.sh` should work, but a full tofu rebuild is the best way to ensure a clean slate.

## Dual Stack Networking
The VLAN and VMs created by Tofu can have IPv6 enabled both on the host level and inside the cluster for dual-stack networking. There are three configurations for IPv6 and dual-stack networking...
1. `ipv6.enabled = false` will disable IPv6 on the host and VLAN. Of course, the cluster will not be dual-stack enabled in this case.
2. `ipv6.enabled = true`, but `ipv6.dual_stack = false` will enable IPv6 on the host and VLAN, but the cluster will only have IPv4 addresses. This is helpful so the hosts can resolve ipv6 addresses, but don't need dual stack services.
3. `ipv6.enabled = true`, and `ipv6.dual_stack = true` will enable IPv6 on the host and VLAN, and the cluster will have both IPv4 and IPv6 addresses. This is the most complex configuration.

Currently, there is no option to have an IPv6-only cluster. This is a complex use case that complicates the setup for various reasons. For example, github's container registry doesn't have an IPv6 address.

*Note: The HA kube-vip apiserver address can be IPv6 without enabling dual-stack.*

# Final Product
### Proxmox Pools with VMs Managed by Tofu
![image](https://github.com/christensenjairus/ClusterCreator/assets/58751387/af2718ea-d38c-4787-a5e3-73e7cb95fd82)

### A Unifi Network with VLAN Managed by Tofu
![image](https://github.com/christensenjairus/ClusterCreator/assets/58751387/ed8bc5a8-dabb-4d5e-9eb2-d2df064a5e33)

### Gamma Example Cluster in K9s
![image](https://github.com/christensenjairus/ClusterCreator/assets/58751387/c998958e-91f8-458d-ad0a-738636238749)

Next, see my [Flux Kubernetes Repo](https://github.com/christensenjairus/Flux-Kubernetes) to see how I orchestrate my K8s infrastructure and applications.
