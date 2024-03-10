# ClusterCreator - Terraform & Ansible K8S on Proxmox
![B1, G1, and Z1 Example Clusters](https://github.com/christensenjairus/ClusterCreator/assets/58751387/2857b24a-eaa5-4951-8b5b-9a9ce358e797)
## Automate the creation of fully functional K8S clusters of any size

This project will assist you in automating the creation of k8s clusters on Proxmox, optionally with a dedicated Unifi network and VLAN.

Terraform & Ansible automate to create external etcd K8S clusters. Terraform creates the VMs and VLANs, and Ansible installs Kubernetes as well as various add-ons for networking, monitoring, storage, and observability.

The Terraform cluster configurations allow for
* Optional external etcd cluster
* Optional Proxmox pool configuration
* Custom Network & VLAN Unifi configuration
* Custom worker classes (general, db, and backup are included - but you can add your own)
* Custom quantities of control-plane, etcd, and custom worker nodes
* Custom hardware requirements for each node class
* Custom node IPs
* Custom proxmox tags

The Ansible playbooks are dynamic to whatever node counts you define. The ansible playbooks include configuration and installation of
* External ETCD cluster (optional)
* Highly available control plane using Kube-VIP
* Containerd CRI
* Cilium CNI with L2 ARP announcements, networking encryption, and Hubble (replacing kube-router, providing eBPF)
* Cluster mesh (optional)
* K8S metrics server
* Vertical pod autoscaler
* Cert-manager with Lets-Encrypt production and staging clusterissuers
* Nginx ingress controller (with custom static ip)
* Kube-state-metrics
* Prometheus (with ingress)
* Grafana (with ingress)
* Longhorn distributed block storage (with ingress and with ephemeral storage class)
* Groundcover dashboard (optional)
* Newrelic monitoring (optional)
* Node labeling
* Gateway API CRDs

*Note: ingresses expose services that do not have passwords, like the Hubble UI. If this is a port-forwarded or BGP setup, you should delete the resulting ingresses until you have a plan to secure them with authorization/authentication.*

## Dynamic configurations
The dynamic nature of terraform + ansible allows the following
* 1 - ∞ control plane nodes
* 0 - ∞ etcd nodes
* 0 - ∞ worker nodes of different classes. The 'classes' are defined by name, cpu, memory, and disk requirements.

## Included Examples

##### Simplest cluster possible - single node, much like the defaults for minikube or kind.

* `b1` cluster (single node cluster)
  * 1 control plane node
    * 8 cores, 8GB RAM, 100GB disk

*Note: Having less than 1 worker node will make ansible untaint the control plane node(s), allowing it to run workloads.*

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
    * 8 cores, 4GB RAM, 50GB disk
  * 5 worker nodes of class `general`
    * 16 cores, 4GB RAM, 100GB disk

*Note: If you add a new worker class, you will need to edit `ansible/helpers/ansible-hosts.txt.j2` to account for it so that it is added to `ansible/tmp/ansible-hosts.txt` at runtime.*

##### Add your own worker types for more flexible node configurations.

* Theoretical overkill cluster
  * 9 control plane nodes
  * 7 external etcd nodes
  * 5 worker nodes of class `backup`
  * 15 worker nodes of class `db`
  * 20 worker nodes of class `general`
  * 5 worker nodes of class `sandbox` # new class
  * 5 worker nodes of class `fedramp` # new class

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
GLOBAL_CLOUDFLARE_API_KEY="<api_key_here>" # used if you have a cloudflare domain for cert-manager clusterissuers
NEWRELIC_LICENSE_KEY="<license_key_here>" # used if you want to monitor your cluster with newrelic
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

### Initialize Terraform
```bash
terraform init
```

### Create your cluster's Terraform workspace
```bash
terraform workspace new <short_cluster_name>
```
This will ensure that your terraform commands only work on the cluster of your choosing. The Terraform configuration relies on the workspace name to know which cluster you'll be working with. You can later use `terraform workspace switch <short_cluster_name>` to switch between clusters.

### Create the VMs with Terraform
```bash
terraform apply [--auto-approve]
``` 
This will clone the template using terraform, create a VLAN in Unifi, and the cluster specifications. This will also create a file called `ansible/tmp/<cluster_name>/cluster_config.json` that tells ansible how the cluster should be configured.

### Install K8S with Ansible
```bash
./create_cluster.sh --cluster_name <full_cluster_name>
```
This will run a series of ansible playbooks to create the cluster. This is independent of the Terraform workspace and uses the `cluster_config.json` file and creates its own `ansible-hosts.txt` file based on the cluster configuration.

### Run Ansible playbooks one at a time
```bash
cd ansible
ansible-playbook -i tmp/$CLUSTER_NAME/ansible-hosts.txt -u $VM_USERNAME <ansible-playbook-name>.yaml
````
Normally all playbooks are run in `./install_k8s.sh`, but you can run them individually if you want to see the output or if you want to run them one at a time. The hosts file has the configuration needed for your cluster, including the cluster name. You should always run these from inside the ansible folder because of various relative paths.

### Uninstall K8S with Ansible
```bash
./uninstall_k8s.sh --cluster_name <full_cluster_name>
```
This will run an ansible playbook to remove k8s the virtual machines.

### Destroy the VMs with Terraform
```bash
terraform destroy [--auto-approve]
```
This will remove the VMs and VLAN from Unifi.

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

## Final Product
### A Unifi Network with VLAN Managed by Terraform
![image](https://github.com/christensenjairus/ClusterCreator/assets/58751387/7529eb65-7aa3-478d-a46f-ff1bafa6c45f)

### Pre-made Grafana Dashboards
![image](https://github.com/christensenjairus/ClusterCreator/assets/58751387/c4597069-e08d-4df6-a1db-0efd6268aea8)

### Prometheus Metrics Query UI
![image](https://github.com/christensenjairus/ClusterCreator/assets/58751387/2d3bffe9-de61-444b-8c41-53ba54538d5e)

### Longhorn Storage UI
![image](https://github.com/christensenjairus/ClusterCreator/assets/58751387/598cf06d-f0d5-4e44-b8ab-1e42c0c6547e)

### NewRelic Monitoring UI


### Groundcover UI
![image](https://github.com/christensenjairus/ClusterCreator/assets/58751387/7adda57b-d831-49f9-bf7d-c228e5d0cc53)

### Hubble eBFP Observability UI
![image](https://github.com/christensenjairus/ClusterCreator/assets/58751387/ab3af8d2-b867-4d9d-a042-b1c10393bf60)

![image](https://github.com/christensenjairus/ClusterCreator/assets/58751387/c52ed90c-9186-4380-8a06-c3638c5a9d34)


