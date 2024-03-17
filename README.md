# ClusterCreator - Terraform & Ansible K8S on Proxmox
![B1, G1, and Z1 Example Clusters](https://github.com/christensenjairus/ClusterCreator/assets/58751387/2857b24a-eaa5-4951-8b5b-9a9ce358e797)
## Automate the creation of fully functional K8S clusters of any size

This project will assist you in automating the creation of k8s clusters on Proxmox, optionally with a dedicated Unifi network and VLAN.

Terraform & Ansible automate to create external etcd K8S clusters. Terraform creates the VMs and VLANs, and Ansible installs Kubernetes as well as various add-ons for networking, monitoring, storage, and observability.

The `create_template.sh` script will create a cloud-init ready virtual machine template for Terraform to use. The template VM includes...
* Install apt packages kubeadm, kubelet, kubectl, helm, containerd, nfs tools, iscsi-tools, qemu-guest-agent, mysql-client, etc
* Installed from source packages cilium cli, hubble cli, cni plugins, etcdctl and vtctldclient
* Updates to operating system
* Various necessary system configurations for k8s, like kernel modules and sysctl settings
* Multipath configuration for Longhorn
* Supports both Ubuntu and Debian images

The Terraform cluster configurations allow for
* Optional external etcd cluster
* Optional Proxmox pool configuration
* Custom Network & VLAN Unifi configuration
* Custom worker classes (general, db, and backup are included - but you can add your own)
* Custom quantities of control-plane, etcd, and custom worker nodes
* Custom hardware requirements for each node class
* Custom node IPs
* Custom proxmox tags

The base Ansible playbooks are dynamic to whatever node counts you define. The Ansible playbooks include configuration and installation of
* External ETCD cluster (optional)
* Highly available control plane using Kube-VIP
* Cilium CNI with L2 ARP announcements, networking encryption, optional clustermesh, and Hubble UI (replacing kube-router, providing eBPF)
* Gateway API CRDs
* Node labeling
* Auto-Provisioning Local StorageClass (rancher) (set as default storageclass)
* Non-Auto-Provisioning Local StorageClass (k8s built-in)

The Ansible playbooks are dynamic to whatever node counts you define. The Ansible playbooks include configuration and installation of
* K8S metrics server
* Vertical pod autoscaler
* Cert-manager with Lets-Encrypt production and staging clusterissuers
* World-Facing Nginx ingress controller (with custom static ip, port forward this one to your router)
* Local-Facing Nginx ingress controller (with custom static ip, create local dns records for this one. Enforces VPN.)
* Kube-state-metrics
* Prometheus (with basic-auth ingress)
* Grafana (with basic-auth ingress)
* Longhorn distributed block storage (with ingress and with ephemeral storage class) (set as default storageclass)
* Groundcover dashboard (optional)
* Newrelic monitoring (optional)
* Kubernetes Dashboard (with basic-auth ingress)
* Hubble UI basic-auth ingress

## Dynamic configurations
The dynamic nature of terraform + Ansible allows the following
* 1 - ∞ control plane nodes
* 0 - ∞ etcd nodes
* 0 - ∞ worker nodes of different classes. The 'classes' are defined by name, cpu, memory, and disk requirements.

## Included Examples

##### Simplest cluster possible - single node, much like the defaults for minikube or kind.

* `b1` cluster (single node cluster)
  * 1 control plane node
    * 16 cores, 16GB RAM, 100GB disk

*Note: Having less than 1 worker node will make Ansible untaint the control plane node(s), allowing it to run workloads.*

##### Add worker nodes of varying types for different workload needs.

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

##### Make the control plane highly available. Add an external etcd cluster. Add more custom workers.

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
    * 8 cores, 4GB RAM, 100GB disk

*Note: If you add a new worker class, you will need to edit `ansible/helpers/ansible-hosts.txt.j2` to account for it so that it is added to `ansible/tmp/ansible-hosts.txt` at runtime.*

##### Add your own worker types for more flexible node configurations.

* Theoretical overkill cluster
  * 9 control plane nodes
  * 7 external etcd nodes
  * 5 worker nodes of class `backup`
  * 15 worker nodes of class `db`
  * 20 worker nodes of class `general`
  * 5 worker nodes of class `sandbox` # possible new class
  * 5 worker nodes of class `fedramp` # possible new class

## Configuration/Secrets Files
Create the following two files.

### For terraform
See [here](https://registry.terraform.io/providers/bpg/proxmox/latest/docs#api-token-authentication) for info on how to get a proxmox user and api token set up for this.
##### `secrets.tf`
Placed in topmost directory
```tf
variable "vm_username" {
    default = "<username here>"
}
variable "vm_password" {
    default = "<password here>"
}
variable "vm_ssh_key" {
    default = "ssh-rsa <key_here> jairuschristensen@macbook-pro.lan"
}
variable "proxmox_username" {
    default = "terraform"
}
variable "proxmox_api_token" {
    default = "terraform@pve!provider=<token_here>"
}
variable "unifi_username" {
    default = "network_service_account"
}
variable "unifi_password" {
    default = "<service_acccount_token>"
}
```

### For the proxmox bash scripts
##### `.env`
Placed in topmost directory.
```bash
# Secrets for ./create_template.sh and ./install_k8s.sh
VM_USERNAME="<username_here>"                 # username for all k8s_vm_template VMs managed by terraform
VM_PASSWORD="<password_here>"                 # user password for all k8s_vm_template VMs managed by terraform

# Secrets for ./install_k8s_addons.sh. All must be defined, but do not have to be valid.
GLOBAL_CLOUDFLARE_API_KEY="<api_key_here>"    # used if you have a cloudflare domain for cert-manager clusterissuers
NEWRELIC_LICENSE_KEY="<license_key_here>"     # used if you want to monitor your cluster with newrelic
SLACK_BOT_TOKEN="xoxb-<rest_of_token_here>"   # used if you want to send alertmanager alerts to slack. Bot must already be in channel.
INGRESS_BASIC_AUTH_USERNAME="<username_here>" # used to secure your ingresses
INGRESS_BASIC_AUTH_PASSWORD="<password_here>" # used to secure your ingresses
```

### Other files that need editing
The other configuration files, listed below, need to be looked through and tweaked to your needs.
* `k8s.env` holds versions of k8s and other software as well as the template vm configuration.
* `vars.tf` holds non-sensitive info for terraform.
* `clusters.tf` holds the cluster configurations.
* `main.tf` holds vm/vlan/pool terraform resources.

## Usage

### Create a cloud-init ready virtual machine template for Terraform to use
```bash
./create_template.sh
```
This will ssh into proxmox and create you a cloud-init ready template. This template is based on the files found in `k8s_vm_template`, `.env`, and `k8s.env`. The vm that is created will start for few minutes install all the necessary packages, then will reset the cloud-init configuration and shut down. The packages installed include containerd, runc, kubeadm, kubelet, kubectl, etcdctl, cilium cli, hubble cli, helm, and other necessary system packages.

### Initialize Terraform
```bash
terraform init
```
This only has to be done once to initialize the terraform modules.

### Create your cluster's Terraform workspace
```bash
terraform workspace new <short_cluster_name>
```
This will ensure that your terraform commands only work on the cluster of your choosing. The Terraform configuration relies on the workspace name to know which cluster you'll be working with. You can later use `terraform workspace switch <short_cluster_name>` to switch between clusters.

### Create the VMs with Terraform
```bash
terraform apply [--auto-approve] [-var="template_vm_id=<vm_id>"]
``` 
This will clone the template using terraform and set cloud-init parameters, as well as create a pool in proxmox, create a VLAN in Unifi, and create the cluster specifications file `ansible/tmp/<cluster_name>/cluster_config.json`. The cluster config file tells Ansible how the cluster should be configured. Default template_vm_id is 9000. 

### Install K8S with Ansible
```bash
./install_k8s.sh --cluster_name <full_cluster_name>
```
This will run a series of Ansible playbooks to create a fresh, minimal cluster. This is independent of the Terraform workspace and uses the `cluster_config.json` file and creates its own `ansible-hosts.txt` file based on the cluster configuration.

### Install K8S Addons with Ansible
```bash
./install_k8s_addons.sh --cluster_name <full_cluster_name>
```
This will guide you through the addons you could install with Ansible. These include features like an ingress controller, metrics server, monitoring, distributed storage, etc.

### Uninstall K8S with Ansible
```bash
./uninstall_k8s.sh --cluster_name <full_cluster_name>
```
This will run an Ansible playbook to reset k8s.

### Destroy the VMs with Terraform
```bash
terraform destroy [--auto-approve]
```
This will remove the VMs, Pool, and VLAN.

### Power on/off your cluster
```bash
./pool_powerctl.sh [--start/--stop] <POOL_NAME> [--timeout <timeout_in_seconds>]
```
This will power on or off the VMs in the specified pool. The timeout is optional and defaults to 300 seconds.

### Installation Errors
`terraform apply` may exit with errors because it is difficult for Proxmox to clone the same template over and over. You may need to run `terraform apply` a few times with larger clusters because of this. Proxmox may also need help if it says that configs already exist or if a VM is not responding. In the worst case scenario, you could manually delete all the VMs, the pool, and the VLAN, and start over.

You may also run into errors while running `./install_k8s.sh`. This script is running `ansible/ansible-master-playbook.yaml`. If you find the issue, you should comment out the already-completed playbooks from `ansible/ansible-master-playbook.yaml` and start the script over to resume roughly where you left off. However, be smart about doing this if there was an error during the etcd node setup, the cp node setup, or the join nodes playbooks because of kubeadm's inability to be run twice without being reset.

If you do need to reset `./uninstall_k8s.sh` should work, but a full terraform rebuild is the best way to ensure a clean slate.

### Don't have a Unifi router or don't want to use VLANs?
To not create a network via Unifi
* Comment out the entire `unifi_network` created `main.tf` . 
* Comment out `depends_on = [unifi_network.vlan]` in the `proxmox_virtual_environment_pool` resource.
* The vlan_id in `clusters.tf` will be ignored now.

*Note: Remember to set your cluster to use an existing network in `clusters.tf` and that your node/lb/vip ips won't conflict with existing devices.*

To use VLANs on your VMs
* Comment out the following from `main.tf` .
```tf
network_device {
    vlan_id = each.value.vlan_id
}
```

### Kubernetes Dashboard
To create a token to login, you'll need to generate a token for your user. This is done with the following command.
```bash
kubectl -n kubernetes-dashboard create token <kube_dashboard_user>
```
Or you could grab the long-lived token to put in your password manager.
```bash
kubectl get secret <kube_dashboard_user> -n kubernetes-dashboard -o jsonpath={".data.token"} | base64 -d
```

## Final Product
### Proxmox Pools with VMs Managed by Terraform
![image](https://github.com/christensenjairus/ClusterCreator/assets/58751387/2857b24a-eaa5-4951-8b5b-9a9ce358e797)

### A Unifi Network with VLAN Managed by Terraform
![image](https://github.com/christensenjairus/ClusterCreator/assets/58751387/7529eb65-7aa3-478d-a46f-ff1bafa6c45f)

### Pre-made Grafana Dashboards
![image](https://github.com/christensenjairus/ClusterCreator/assets/58751387/c4597069-e08d-4df6-a1db-0efd6268aea8)

### Prometheus Metrics Query UI
![image](https://github.com/christensenjairus/ClusterCreator/assets/58751387/2d3bffe9-de61-444b-8c41-53ba54538d5e)

### Longhorn Storage UI
![image](https://github.com/christensenjairus/ClusterCreator/assets/58751387/598cf06d-f0d5-4e44-b8ab-1e42c0c6547e)

### NewRelic Monitoring UI
![image](https://github.com/christensenjairus/ClusterCreator/assets/58751387/6176acdd-252a-4b32-bdbe-ab80d0fe8f38)

### Groundcover UI
![image](https://github.com/christensenjairus/ClusterCreator/assets/58751387/7adda57b-d831-49f9-bf7d-c228e5d0cc53)

### Hubble eBFP Observability UI
![image](https://github.com/christensenjairus/ClusterCreator/assets/58751387/ab3af8d2-b867-4d9d-a042-b1c10393bf60)

![image](https://github.com/christensenjairus/ClusterCreator/assets/58751387/c52ed90c-9186-4380-8a06-c3638c5a9d34)

### Kubernetes Dashboard
![image](https://github.com/christensenjairus/ClusterCreator/assets/58751387/73d95fbb-6a3a-4fce-a051-3d0113367ffe)
