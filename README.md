# Cluster Creator - Terraform & Ansible K8S on Proxmox
![image](https://github.com/christensenjairus/ClusterCreator/assets/58751387/e37b5e75-990a-4931-be12-dd9d466f7c07)
## Create a K8S cluster in three commands or less

This project will assist you in automating the creation of k8s clusters on Proxmox, optionally with a dedicated Unifi network and VLAN.

Terraform & Ansible automate to create external etcd K8S clusters. Terraform creates the VMs and VLANs, and Ansible installs Kubernetes as well as various add-ons for networking, monitoring, storage, and observability.

The Terraform cluster configurations allow for
* Optional external etcd cluster
* Optional Proxmox pool configuration
* Custom Network & VLAN Unifi configuration
* Custom worker types (general, db, and backup are included - but you can add your own)
* Custom quantities of control-plane, etcd, and custom worker nodes
* Custom hardware requirements for each node type
* Custom node IPs
* Custom proxmox tags

The Ansible playbooks are dynamic to whatever node counts you define. The ansible playbooks include configuration and installation of
* External ETCD cluster (optional)
* Highly available control plane using Kube-VIP
* Containerd CRI
* Cilium CNI with L2 ARP announcements, networking encryption, and Hubble (replacing kube-router, providing eBPF)
* K8S metrics server
* Vertical pod autoscaler
* Cert-manager with Lets-Encrypt production and staging clusterissuers
* Nginx ingress controller (with custom static ip)
* Kube-state-metrics
* Prometheus (with ingress)
* Grafana (with ingress)
* Longhorn distributed block storage (with ingress and with ephemeral storage class)
* Groundcover dashboard (optional)

*Note: ingresses expose services that do not have passwords, like the Hubble UI. If this is a port-forwarded or BGP setup, you should delete the resulting ingresses until you have a plan to secure them with authorization/authentication.*

## Dynamic configurations
The dynamic nature of terraform + ansible allows the following
* 1 - ∞ control plane nodes
* 0 - ∞ etcd nodes
* 0 - ∞ worker nodes of different types. The 'types' are defined by name, cpu, memory, and disk requirements.

## Examples:

Simplest cluster possible - single node.

* `b1` cluster (single node cluster)
  * 1 control plane node
    * 8 cores, 8GB RAM, 100GB disk

*Note: Having less than 1 worker node will make ansible untaint the control plane node, allowing it to run workloads.*

![image](https://github.com/christensenjairus/ClusterCreator/assets/58751387/e2130a29-efea-4f6a-bd71-819becac3b07)

Make the control plane highly available, add an external etcd cluster, and 3 worker nodes...


* `g1` cluster
  * 3 control plane node
    * 4 cores, 4GB RAM, 30GB disk
  * 3 external etcd node
    * 2 cores, 2GB RAM, 30GB disk
  * 3 worker nodes of type `general`
    * 8 cores, 8GB RAM, 100GB disk

*Note: etcd nodes are not shown in cluster, but they are used by the control plane nodes.*

![image](https://github.com/christensenjairus/ClusterCreator/assets/58751387/fd35e1c7-a011-488e-b0f4-ca881dc7732c)

Raise the control plane and etcd clusters to 5. Add some custom worker types.

* `z1` cluster
  * 5 control plane nodes
    * 4 cores, 4GB RAM, 30GB disk
  * 5 external etcd nodes
    * 2 cores, 2GB RAM, 30GB disk
  * 5 worker nodes of type `general`
    * 16 cores, 4GB RAM, 30GB disk
  * 3 worker nodes of type `db`
    * 8 cores, 4GB RAM, 30GB disk
  * 2 worker nodes of type `backup`
    * 4 cores, 2GB RAM, 30GB disk

*Note: If you add a new worker type, you will need to edit `ansible/helpers/ansible-hosts.txt.j2` to account for it so that it is added to `ansible/tmp/ansible-hosts.txt` at runtime.*

![image](https://github.com/christensenjairus/ClusterCreator/assets/58751387/45ea08c7-6bb4-4463-a01c-ba02c4301343)

## Configuration/Secrets Files
Create the following two files.

### For terraform
See [here](https://registry.terraform.io/providers/bpg/proxmox/latest/docs#api-token-authentication) for info on how to get a proxmox user and api token set up for this.
```tf
# secrets.tf (placed in topmost directory)
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
```bash
### .env (placed in topmost directory)
VM_USERNAME="<username_here>"
VM_PASSWORD="<password_here>"
NON_PASSWORD_PROTECTED_SSH_KEY="id_rsa" # assumed that this is in ~/.ssh/ and the .pub file is named similarly
GLOBAL_CLOUDFLARE_API_KEY="<api_key_here>"
PROXMOX_USERNAME=root
PROXMOX_HOST="10.0.0.100"
PROXMOX_ISO_PATH="/var/lib/pve/local-btrfs/template/iso/"
IMAGE_NAME="jammy-server-cloudimg-amd64.img" # normally the kvm.img would be fine, but cilium needs a full kernel for eBPF
IMAGE_LINK="https://cloud-images.ubuntu.com/jammy/current/${IMAGE_NAME}"
TIMEZONE="America/Denver"
TEMPLATE_VM_ID=9000
TEMPLATE_VM_GATEWAY="10.0.0.1"
TEMPLATE_VM_IP="10.0.0.10/24"
TEMPLATE_VM_SEARCH_DOMAIN="lan"
TWO_DNS_SERVERS="1.1.1.1 1.0.0.1"
```

### Other files that need editing
The other configuration files, listed below, need to be looked through and tweaked to your needs. Much of the information in these files is redundant to the .env file. Change both.
* `vars.tf` holds non-sensitive info for terraform.
* `clusters.tf` holds the cluster configurations. You will need edit this to your needs!
* `main.tf` holds vm configurations.

## Usage

### Create a cloud-init ready virtual machine template for Terraform to use
```bash
./create_template.sh
```
This will ssh into proxmox and create you a cloud-init ready template.

### Create the VMs with Terraform
```bash
terraform workspace new <cluster_name>
````` 
This will create a new workspace for the cluster. 

*Note: Terraform relies on its workspaces to manage the cluster configurations, meaning you will need to run `terraform workspace select <cluster_name>` to select the cluster you want to manage. (`g1` is the default workspace)*

```bash
terraform apply
``` 
This will clone the template using terraform, create a VLAN in Unifi, and the cluster specifications.

### Install K8S with Ansible
```bash
./create_cluster.sh
```
This will run a series of ansible playbooks to create the cluster.

*Note: `terraform apply` controls the cluster configuration file that ansible uses, found at `ansible/tmp/cluster_config.json`. If you plan on switching which cluster you want Ansible to interact with, you must run `terraform workspace select <cluster_name>` then re-run `terraform apply` again with the new cluster name.*

### Uninstall K8S with Ansible
```bash
./uninstall_k8s.sh
```
This will run an ansible playbook to remove k8s the virtual machines.

### Destroy the VMs with Terraform
```bash
terraform destroy
```
This will remove the VMs and VLAN from Unifi.

### Installation Errors
`terraform apply` may exit with errors because it is difficult for Proxmox to clone the same template over and over. You may need to run `terraform apply` a few times with larger clusters because of this. Proxmox may also need help if it says that configs already exist or if a VM is not responding. In the worst case scenario, you could manually delete all the VMs, the pool, and the VLAN, and start over.

You may also run into errors while running `./install_k8s.sh`. This script is running `ansible/ansible-master-playbook.yaml`. If you find the issue, you should comment out the already-completed playbooks from `ansible/ansible-master-playbook.yaml` and start the script over to resume roughly where you left off. However, be smart about doing this if there was an error during the etcd node setup, the cp node setup, or the join nodes playbooks because of kubeadm's inability to be run twice without being reset.

If you do need to reset `./uninstall_k8s.sh` should do the trick. But a full terraform rebuild is the best way to ensure a clean slate.

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

## Final Product
### A Unifi Network with VLAN Managed by Terraform
![image](https://github.com/christensenjairus/ClusterCreator/assets/58751387/7529eb65-7aa3-478d-a46f-ff1bafa6c45f)

### Pre-made Grafana Dashboards
![image](https://github.com/christensenjairus/ClusterCreator/assets/58751387/c4597069-e08d-4df6-a1db-0efd6268aea8)

### Prometheus Metrics Query UI
![image](https://github.com/christensenjairus/ClusterCreator/assets/58751387/2d3bffe9-de61-444b-8c41-53ba54538d5e)

### Longhorn Storage UI
![image](https://github.com/christensenjairus/ClusterCreator/assets/58751387/598cf06d-f0d5-4e44-b8ab-1e42c0c6547e)

### Groundcover UI
![image](https://github.com/christensenjairus/ClusterCreator/assets/58751387/7adda57b-d831-49f9-bf7d-c228e5d0cc53)

### Hubble eBFP Observability UI
![image](https://github.com/christensenjairus/ClusterCreator/assets/58751387/ab3af8d2-b867-4d9d-a042-b1c10393bf60)

![image](https://github.com/christensenjairus/ClusterCreator/assets/58751387/c52ed90c-9186-4380-8a06-c3638c5a9d34)


