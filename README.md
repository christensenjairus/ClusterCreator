# ClusterCreator: Terraform & Ansible K8S Bootstrapping on Proxmox

![ClusterCreator Overview](https://github.com/user-attachments/assets/01cbdc3a-43e7-450b-8664-954bc8f0bcb7)

## Table of Contents

1. [Introduction](#introduction)
2. [Features](#features)
3. [Prerequisites](#prerequisites)
4. [Installation](#installation)
   - [1. Add Proxmox Cluster User](#1-add-proxmox-cluster-user)
   - [2. Configure Secrets Files](#2-configure-secrets-files)
   - [3. Edit Configuration Files](#3-edit-configuration-files)
5. [Usage](#usage)
   - [1. Create a VM Template](#1-create-a-vm-template)
   - [2. Initialize Tofu](#2-initialize-tofu)
   - [3. Create Tofu Workspace](#3-create-tofu-workspace)
   - [4. Create VMs with Tofu](#4-create-vms-with-tofu)
   - [5. Install Kubernetes with Ansible](#5-install-kubernetes-with-ansible)
   - [6. Manage Kubernetes Clusters](#6-manage-kubernetes-clusters)
6. [Examples](#examples)
   - [Alpha Cluster: Single Node](#alpha-cluster-single-node)
   - [Beta Cluster: Multiple General Workers](#beta-cluster-multiple-general-workers)
   - [Gamma Cluster: Highly Available Control Plane with Decoupled etcd](#gamma-cluster-highly-available-control-plane-with-decoupled-etcd)
7. [Advanced Configurations](#advanced-configurations)
   - [Dynamic Configurations](#dynamic-configurations)
   - [Dual Stack Networking](#dual-stack-networking)
   - [Custom Worker Types](#custom-worker-types)
8. [Troubleshooting](#troubleshooting)
9. [Final Product](#final-product)
10. [Additional Resources](#additional-resources)

---

## Introduction

**ClusterCreator** automates the creation and maintenance of fully functional Kubernetes (K8S) clusters of any size on Proxmox. Leveraging Terraform/OpenTofu and Ansible, it facilitates complex setups, including decoupled etcd clusters, diverse worker node configurations, and optional integration with Unifi networks and VLANs.

Having a virtualized K8S cluster allows you to not only simulate a cloud environment but also scale and customize your cluster to your needs—adding or removing nodes and disks, managing backups and snapshots of the virtual machine disks, customizing node class types, and controlling state.

[Watch a step-by-step demo on my blog](https://cyber-engine.com/blog/2024/06/25/k8s-on-proxmox-using-clustercreator/).

---

## Features

- **Automated VM and VLAN Creation**: Utilize OpenTofu to create VMs and VLANs tailored to your cluster needs.
- **Kubernetes Installation and Configuration**: Ansible playbooks handle the installation of Kubernetes and essential add-ons.
- **Scalable Cluster Management**: Easily add or remove nodes, customize node classes, and manage hardware requirements.
- **Optional Unifi Network Integration**: Configure dedicated networks and VLANs with Unifi.
- **Highly Available Control Plane**: Implement HA control planes using Kube-VIP.
- **Customizable Networking**: Support for dual-stack networking (IPv4 & IPv6).
- **Dynamic Worker Classes**: Define worker nodes with varying CPU, memory, disk, and networking specifications.

---

## Prerequisites

Before proceeding, ensure you have the following:

- **Proxmox VE**: A running Proxmox cluster.
- **Unifi Controller** (optional): For managing networks and VLANs.
- **Terraform/OpenTofu**: Installed and configured.
- **Ansible**: Installed on your control machine.
- **Access Credentials**: For Proxmox and Unifi (if used).

---

## Installation

### 1. Add Proxmox Cluster User

ClusterCreator requires access to the Proxmox cluster. Execute the following commands on your Proxmox server to create a datacenter user:

#### 1. Add a Proxmox User:

```shell
pveum user add terraform@pve -comment "Terraform User"
```

#### 2. Add a Custom Role for Terraform with Required Permissions:

```shell
pveum role add TerraformRole -privs "Datastore.Allocate Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit Pool.Allocate Pool.Audit Sys.Audit Sys.Console Sys.Modify SDN.Use VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.Monitor VM.PowerMgmt User.Modify Mapping.Use"
```

#### 3. Assign the Role to the User at the Datacenter Level:

```shell
pveum aclmod / -user terraform@pve -role TerraformRole
```

#### 4. Create an API Token for the User:

```shell
sudo pveum user token add terraform@pve provider --privsep=0
```

For additional documenation see [Proxmox API Token Authentication](https://registry.terraform.io/providers/bpg/proxmox/latest/docs#api-token-authentication).

### 2. Configure Secrets Files

#### For Tofu (Terraform)

Rename and edit secrets.tf.example to secrets.tf. These secrets are used by Tofu to interact with Proxmox and Unifi.

```bash
cp secrets.tf.example secrets.tf
```

- **Proxmox Credentials**: Refer to for creating API tokens.
- **Unifi Credentials**: Create a service account in the Unifi Controller with Site Admin permissions for the Network app.

#### Environment Variables For Bash

Rename and edit `.env.example` to `.env`. These secrets are used in bash scripts for VM operations.

```bash
cp .env.example .env
```

**Note**: There may be overlapping configurations between secrets.tf and .env.

### 3. Edit Configuration Files

Customize the following configuration files to suit your environment:

- `k8s.env`: Specify Kubernetes versions and template VM configurations.
- `vars.tf`: Define non-sensitive variables for Tofu.
- `clusters.tf`: Configure cluster specifications. Update the username to your own.
- `main.tf`: Manage VM, VLAN, and pool resources with Tofu.

---

## Usage

### 1. Create a VM Template

Run the `create_template.sh` script to generate a cloud-init ready VM template for Tofu.

```bash
./create_template.sh
```

What It Does:

- Installs necessary apt packages (e.g., kubeadm, kubelet, kubectl, helm).
- Compiles and installs packages from source (e.g., cilium CLI, etcdctl).
- Updates the operating system.
- Configures system settings for Kubernetes (kernel modules, sysctl).
- Sets up multipath configuration for storage systems like Longhorn.
- Supports both Ubuntu and Debian images.

**Outcome**: A VM template that installs all required packages and configurations, ready for cloud-init.

### 2. Initialize Tofu

Initialize Tofu modules. This step is required only once.

```bash
tofu init
```

### 3. Create Tofu Workspace

Create a dedicated workspace for your cluster.

```bash
tofu workspace new <cluster_name>
```

**Purpose**: Ensures Tofu commands are scoped to the specified cluster. Switch between workspaces using:

```bash
tofu workspace switch <cluster_name>
```

### 4. Create VMs with Tofu

Apply the Tofu configuration to create VMs and related resources.

```bash
tofu apply [--auto-approve] [-var="template_vm_id=<vm_id>"]
```

Functionality:

- Clones the VM template.
- Sets cloud-init parameters.
- Creates a Proxmox pool and Unifi VLAN (if configured).
- Generates `cluster_config.json` for Ansible.

Default `template_vm_id`: 9000

### 5. Install Kubernetes with Ansible

Run the Ansible playbooks to set up Kubernetes.

```bash
./install_k8s.sh -n/--cluster_name <CLUSTER_NAME> [-a/--add-nodes]
```

**Options**:

- `--add-nodes`: Adds new nodes to an existing cluster.

Includes:

- Optional decoupled etcd cluster setup.
- Highly available control plane with Kube-VIP.
- Cilium CNI (with optional dual-stack networking).
- MetalLB (with L2 advertisements).
- Metrics server installation.
- Node labeling and tainting.
- StorageClass configuration.
- Node preparation and joining.

**Note**: Avoid using `--add-nodes` for setting up or editing a decoupled etcd cluster.

### 6. Manage Kubernetes Clusters

#### Kubeconfig Files

Configure your `kubeconfig` to interact with the clusters:

```bash
export KUBECONFIG=~/.kube/config:~/.kube/alpha.yml:~/.kube/beta.yml:~/.kube/gamma.yml
```

**Tip**: Add the export command to your shell's configuration file (`~/.bashrc` or `~/.zshrc`) for persistence.

Use tools like `kubectx` or `kubie` to switch between contexts.

#### Drain or Remove a Node

Remove a node from the cluster:

```bash
./remove_node.sh -n/--cluster-name <CLUSTER_NAME> -h/--hostname <NODE_HOSTNAME> -t/--timeout <TIMEOUT_SECONDS> [-d/--delete]
```

**Options**:

- `--delete`: Deletes and resets the node for fresh re-commissioning.

**Note**: Not applicable for decoupled etcd nodes.

#### Uninstall Kubernetes

Reset the Kubernetes cluster:

```bash
./uninstall_k8s.sh -n/--cluster_name <CLUSTER_NAME> [-h/--single-hostname <HOSTNAME_TO_RESET>]
```

**Options**:

- `--single-hostname`: Resets a specific node. Without this, all nodes are reset, and the cluster is deleted.

#### Destroy VMs with Tofu

Remove VMs, pools, and VLANs:

```bash
tofu destroy [--auto-approve] [--target='proxmox_virtual_environment_vm.node["<vm_name>"]']
```

**Options**:

- `--target`: Specifies particular VMs to destroy.

#### Power Control

Manage VM power states:

```bash
./powerctl_pool.sh [--start|--shutdown|--pause|--resume|--hibernate|--stop] <POOL_NAME> [--timeout <timeout_in_seconds>]
```

**Requirements**: QEMU Guest Agent must be running on VMs.

#### Run Commands on Host Groups

Execute bash commands on specified Ansible host groups:

```bash
./run_command_on_host_group.sh [-n/--cluster-name <CLUSTER_NAME>] [-g/--group <GROUP_NAME>] [-c/--command '<command>']
```

**Example**:

```bash
./run_command_on_host_group.sh -n mycluster -g all -c 'sudo apt update'
```

---

## Examples

### Alpha Cluster: Single Node

A minimal cluster resembling Minikube or Kind.

- **Cluster Name**: `alpha`
- **Control Plane**:
  - **Nodes**: 1
  - **Specifications**: 16 CPU cores, 16GB RAM, 100GB disk

**Note**: Less than one worker node results in the control plane being untainted, allowing it to run workloads.

### Beta Cluster: Multiple General Workers

Expand with additional worker nodes for diverse workloads.

- **Cluster Name**: `beta`
- **Control Plane**:
  - **Nodes**: 1
  - **Specifications**: 4 CPU cores, 4GB RAM, 30GB disk
- **Workers**:
  - **Nodes**: 2 (class: `general`)
  - **Specifications**: 8 CPU cores, 4GB RAM, 30GB disk each

**Note**: etcd nodes are utilized by control plane nodes but are not explicitly shown.

### Gamma Cluster: Highly Available Control Plane with Decoupled etcd

A robust setup with multiple control and etcd nodes, including GPU workers.

- **Cluster Name**: `gamma`
- **Control Plane**:
  - **Nodes**: 3
  - **Specifications**: 4 CPU cores, 4GB RAM, 30GB disk each
- **Decoupled etcd**:
  - **Nodes**: 3
  - **Specifications**: 2 CPU cores, 2GB RAM, 30GB disk each
- **Workers**:
  - **General Nodes**: 5
    - **Specifications**: 8 CPU cores, 4GB RAM, 30GB disk
  - **GPU Nodes**: 2
    - **Specifications**: 2 CPU cores, 2GB RAM, 20GB disk, with attached GPUs

---

## Advanced Configurations

### Dynamic Configurations

Leverage OpenTofu and Ansible to create highly dynamic cluster configurations:

- **Control Plane Nodes**: 1 to ∞
- **etcd Nodes**: 0 to ∞
- **Worker Nodes**: 0 to ∞, with varying classes (defined by name, CPU, memory, disk, networking, labels)

### Dual Stack Networking

Configure IPv4 and IPv6 support:

1. **IPv6 Disabled**:

- `ipv6.enabled = false`
- Cluster operates with IPv4 only.

2. **IPv6 Enabled, Single Stack**:

- `ipv6.enabled = true`
- `ipv6.dual_stack = false`
- Host and VLAN have IPv6, but the cluster uses IPv4.

3. **IPv6 Enabled, Dual Stack**:

- `ipv6.enabled = true`
- `ipv6.dual_stack = true`
- Both IPv4 and IPv6 are active within the cluster.

**Note**: IPv6-only clusters are not supported due to complexity and external dependencies (e.g., GitHub Container Registry lacks IPv6).

**Tip**: The HA kube-vip API server can utilize an IPv6 address without enabling dual-stack.

### Custom Worker Types

Define custom worker classes in `clusters.tf` to meet specific workload requirements:

- **GPU Workers**:

  - **Example**: Already implemented in `clusters.tf`
  - **Use Case**: AI and machine learning workloads.

- **Storage Workers**:

  - **Configuration**: Extra disks, taints for storage systems like Rook.

- **Database Workers**:

  - **Configuration**: Increased memory for database operations.

- **FedRAMP Workers**:

  - **Configuration**: Taints to restrict workloads to government containers.

- **Backup Workers**:
  - **Configuration**: Reduced CPU and memory, expanded disks, taints for backup storage.

---

## Troubleshooting

### Installation Errors

**Common Issues**:

- **Proxmox Clone Failures**: Proxmox may struggle with cloning identical templates repeatedly. \
  **Solution**:

  - Retry `tofu apply` multiple times with larger cluster sizes.
  - Add nodes in smaller batches to distribute across the Proxmox cluster.

- **Configuration Conflicts**: Errors related to existing configurations or unresponsive VMs. \
  **Solution**:
  - Ensure no conflicting resources exist before applying.
  - Use `./uninstall_k8s.sh` to reset VMs if necessary.

**Workaround**: For persistent issues, create brand-new VMs to ensure a clean environment.

---

## Final Product

### Proxmox Pools with VMs Managed by Tofu

![image](https://github.com/user-attachments/assets/8ab9ddc7-48a0-4dff-a3b6-c96aaf251a50)

### Unifi Network with VLAN Managed by Tofu

![image](https://github.com/user-attachments/assets/a6af26ca-c711-4744-8067-354d7e5152ac)

### Gamma Cluster Example in K9s

![image](https://github.com/user-attachments/assets/e8d7e2ef-c757-41cc-8765-da361bfb4a67)

## Additional Resources

- **Flux Kubernetes Repository**: [christensenjairus/Flux-Kubernetes](https://github.com/christensenjairus/Flux-Kubernetes) \
  Explore how to orchestrate Kubernetes infrastructure and applications using infrastructure as code with Flux.
