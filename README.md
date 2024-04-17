# ClusterCreator - OpenTofu & Ansible K8S on Proxmox
![B1, G1, and Z1 Example Clusters](https://github.com/christensenjairus/ClusterCreator/assets/58751387/2857b24a-eaa5-4951-8b5b-9a9ce358e797)
## Automate the creation of fully functional K8S clusters of any size on Proxmox

This project will assist you in automating the creation of k8s clusters on Proxmox, optionally with a dedicated Unifi network and VLAN.

OpenTofu & Ansible automate to create external etcd K8S clusters. OpenTofu creates the VMs and VLANs, and Ansible installs Kubernetes as well as various add-ons for networking, monitoring, storage, and observability.

##### The `create_template.sh` script will create a cloud-init ready virtual machine template for Tofu to use. The template VM includes
* Install apt packages kubeadm, kubelet, kubectl, helm, containerd, nfs tools, iscsi-tools, qemu-guest-agent, mysql-client, ceph, etc.
* Installed from source packages cilium cli, hubble cli, cni plugins, etcdctl, vtctldclient, and vtexplain
* Updates to operating system
* Various necessary system configurations for k8s, like kernel modules and sysctl settings
* Multipath configuration (needed for Longhorn)
* Supports both Ubuntu and Debian images

##### The Tofu cluster configuration allows for
* Optional external etcd cluster
* Proxmox pool configuration
* Custom Network & VLAN Unifi configuration (optional)
* Custom worker classes (general, db, and backup are included - but you can add your own)
* Custom quantities of control-plane, etcd, and custom worker nodes
* Custom hardware requirements for each node class
* Custom disk configurations
* Custom node IPs
* Custom proxmox tags

##### `./install_k8s.sh` runs a series of Ansible playbooks to create a fresh, minimal cluster. The Ansible playbooks include configuration and installation of
* External ETCD cluster (optional)
* Highly available control plane using Kube-VIP
* Cilium CNI (replacing kube-router, providing full eBPF)
* Metrics server
* Node labeling
* Auto-Provisioning Local StorageClass (rancher)
* Non-Auto-Provisioning Local StorageClass (k8s built-in) (set as default StorageClass)

# Usage

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
tofu apply [--auto-approve] [-var="template_vm_id=<vm_id>"]
``` 
This will clone the template using tofu and set cloud-init parameters, as well as create a pool in proxmox, create a VLAN in Unifi, and create the cluster specifications file `ansible/tmp/<cluster_name>/cluster_config.json`. The cluster config file tells Ansible how the cluster should be configured. Default template_vm_id is 9000. 

### Install K8S with Ansible
```bash
./install_k8s.sh --cluster_name <cluster_name>
```
This will run a series of Ansible playbooks to create a fresh, minimal cluster. This is independent of the Tofu workspace and uses the `cluster_config.json` file and creates its own `ansible-hosts.txt` file based on the cluster configuration.

### Uninstall K8S with Ansible
```bash
./uninstall_k8s.sh --cluster_name <cluster_name>
```
This will run an Ansible playbook to reset k8s.

### Destroy the VMs with Tofu
```bash
tofu destroy [--auto-approve]
```
This will remove the VMs, Pool, and VLAN.

### Power on/off your cluster
```bash
./powerctl_pool.sh [--start|--shutdown|--pause|--resume|--hibernate|--stop] <POOL_NAME> [--timeout <timeout_in_seconds>]
```
This will perform QEMU power control functions for the VMs in the specified pool. The timeout is optional, only applied for start/stop/shutdown, and defaults to 300 seconds. Pools are in all-caps. Requires the qemu-guest-agent to be running in the VM.

### Run bash commands on ansible host groups
```bash
./run_command_on_host_group.sh [--n/--cluster-name <CLUSTER_NAME> [-g/--group <GROUP_NAME>] [-c/--command '<command>']
```
This will run bash commands on the ansible host group you define. 'all' is the default group name. Multiple groups can be chained together with a comma and surrounding quotations.

# Dynamic configurations
The dynamic nature of OpenTofu + Ansible allows the following
* 1 - ∞ control plane nodes
* 0 - ∞ etcd nodes
* 0 - ∞ worker nodes of different classes. The 'classes' are defined by name, cpu, memory, and disk requirements.

# Included Examples

### Simplest cluster possible - single node, much like the defaults for minikube or kind

* `b1` cluster (single node cluster)
  * 1 control plane node
    * 16 cores, 16GB RAM, 100GB disk

*Note: Having less than 1 worker node will make Ansible untaint the control plane node(s), allowing it to run workloads.*

### Add worker nodes of varying types for different workload needs

* `g1` cluster
  * 1 control plane node
    * 4 cores, 4GB RAM, 30GB disk
  * 1 worker node of class `backup`
    * 2 cores, 2GB RAM, 100GB disk
  * 1 worker node of class `db`
    * 4 cores, 8GB RAM, 50GB disk
  * 1 worker node of class `general`
    * 8 cores, 4GB RAM, 100GB disk

*Note: etcd nodes are not shown in cluster, but they are used by the control plane nodes.*

### Make the control plane highly available. Add an external etcd cluster. Add more custom workers

* `z1` cluster
  * 3 control plane nodes
    * 4 cores, 4GB RAM, 30GB disk
  * 3 external etcd nodes
    * 2 cores, 2GB RAM, 30GB disk
  * 2 worker nodes of class `backup`
    * 2 cores, 2GB RAM, 100GB disk
  * 3 worker nodes of class `db`
    * 4 cores, 8GB RAM, 50GB disk
  * 5 worker nodes of class `general`
    * 8 cores, 4GB RAM, 30GB os disk, 100GB extra disk (for a future ceph cluster)

*Note: If you add a new worker class, you will need to edit `ansible/helpers/ansible-hosts.txt.j2` to account for it so that it is added to `ansible/tmp/ansible-hosts.txt` at runtime.*

### Add your own worker types for more flexible node configurations

* Theoretical overkill cluster
  * 9 control plane nodes
  * 7 external etcd nodes
  * 5 worker nodes of class `backup`
  * 15 worker nodes of class `db`
  * 20 worker nodes of class `general`
  * 5 worker nodes of class `sandbox` # possible new class
  * 5 worker nodes of class `fedramp` # possible new class
  * 5 worker nodes of class `storage` # possible new class

# Configuration/Secrets Files
Create the following two files.

## For Tofu
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
    default = "tofu" # change me to your tofu service account username
}
variable "proxmox_api_token" {
    default = "tofu@pve!provider=<token_here>"
}
variable "unifi_username" {
    default = "network_service_account" # change me to your unifi service account username
}
variable "unifi_password" {
    default = "<service_acccount_token>"
}
```

## For bash
#### `.env`
Placed in topmost directory.
```bash
# Secrets for ./create_template.sh and ./install_k8s.sh
VM_USERNAME="<username_here>"                 # username for all k8s_vm_template VMs managed by tofu
VM_PASSWORD="<password_here>"                 # user password for all k8s_vm_template VMs managed by tofu
```

## Other files that need editing
The other configuration files, listed below, need to be looked through and tweaked to your needs.
* `k8s.env` holds versions of k8s and other software as well as the template vm configuration.
* `vars.tf` holds non-sensitive info for tofu.
* `clusters.tf` holds the cluster configurations. Make sure to change the username in this file to your own username.
* `main.tf` holds vm/vlan/pool tofu resources.

## Installation Errors
`tofu apply` may exit with errors because it is difficult for Proxmox to clone the same template over and over. You may need to run `tofu apply` a few times with larger clusters because of this. Proxmox may also need help if it says that configs already exist or if a VM is not responding. In the worst case scenario, you could manually delete all the VMs, the pool, and the VLAN, and start over.

You may also run into errors while running `./install_k8s.sh`. This script is running `ansible/ansible-master-playbook.yaml`. If you find the issue, you should comment out the already-completed playbooks from `ansible/ansible-master-playbook.yaml` and start the script over to resume roughly where you left off. However, be smart about doing this if there was an error during the etcd node setup, the cp node setup, or the join nodes playbooks because of kubeadm's inability to be run twice without being reset.

If you do need to reset `./uninstall_k8s.sh` should work, but a full tofu rebuild is the best way to ensure a clean slate.

# Final Product
### Proxmox Pools with VMs Managed by Tofu
![image](https://github.com/christensenjairus/ClusterCreator/assets/58751387/2857b24a-eaa5-4951-8b5b-9a9ce358e797)

### A Unifi Network with VLAN Managed by Tofu
![image](https://github.com/christensenjairus/ClusterCreator/assets/58751387/7529eb65-7aa3-478d-a46f-ff1bafa6c45f)

### Z1 Example Cluster in K9s
![image](https://github.com/christensenjairus/ClusterCreator/assets/58751387/15a6896a-86df-49bb-8a95-711f2847b950)

