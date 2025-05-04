# ClusterCreator: Terraform & Ansible K8s on Proxmox

![ClusterCreator Overview](https://github.com/user-attachments/assets/01cbdc3a-43e7-450b-8664-954bc8f0bcb7)

## Table of Contents

- [ClusterCreator: Terraform \& Ansible K8s on Proxmox](#clustercreator-terraform--ansible-k8s-on-proxmox)
  - [Table of Contents](#table-of-contents)
  - [Star History](#star-history)
  - [Introduction](#introduction)
  - [Features](#features)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
    - [1. Add Proxmox Cluster User](#1-add-proxmox-cluster-user)
      - [1. Add a Proxmox User:](#1-add-a-proxmox-user)
      - [2. Add a Custom Role for Tofu with Required Permissions:](#2-add-a-custom-role-for-tofu-with-required-permissions)
      - [3. Assign the Role to the User at the Datacenter Level:](#3-assign-the-role-to-the-user-at-the-datacenter-level)
      - [4. Create an API Token for the User:](#4-create-an-api-token-for-the-user)
    - [2. Add a KUBECONFIG line to your .bashrc or .zshrc](#2-add-a-kubeconfig-line-to-your-bashrc-or-zshrc)
    - [3. Setup a `ccr` alias](#3-setup-a-ccr-alias)
    - [4. Configure Additional Providers (optional)](#4-configure-additional-providers-optional)
    - [5. Configure Variables](#5-configure-variables)
    - [6. Configure Secrets](#6-configure-secrets)
    - [7. Configure Clusters](#7-configure-clusters)
  - [Usage](#usage)
    - [1. Create a VM Template](#1-create-a-vm-template)
    - [2. Initialize Tofu](#2-initialize-tofu)
    - [3. Set Cluster Context](#3-set-cluster-context)
    - [4. Create VMs with Tofu](#4-create-vms-with-tofu)
    - [5. Bootstrap Kubernetes](#5-bootstrap-kubernetes)
    - [6. Manage Kubernetes Clusters](#6-manage-kubernetes-clusters)
  - [Examples](#examples)
    - [Alpha Cluster: Single Node](#alpha-cluster-single-node)
    - [Beta Cluster: Multiple General Workers](#beta-cluster-multiple-general-workers)
    - [Gamma Cluster: Highly Available Control Plane with Decoupled etcd](#gamma-cluster-highly-available-control-plane-with-decoupled-etcd)
  - [Advanced Configurations](#advanced-configurations)
    - [Dynamic Configurations](#dynamic-configurations)
    - [Dual Stack Networking](#dual-stack-networking)
    - [Custom Worker Types](#custom-worker-types)
  - [Troubleshooting](#troubleshooting)
    - [Installation Errors](#installation-errors)
  - [Final Product](#final-product)
    - [Proxmox Pools with VMs Managed by Tofu](#proxmox-pools-with-vms-managed-by-tofu)
    - [Unifi Network with VLAN Managed by Tofu](#unifi-network-with-vlan-managed-by-tofu)
    - [Gamma Cluster Example in K9s](#gamma-cluster-example-in-k9s)

---

## Star History

<a href="https://www.star-history.com/#christensenjairus/clustercreator&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=christensenjairus/clustercreator&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=christensenjairus/clustercreator&type=Date" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=christensenjairus/clustercreator&type=Date" />
 </picture>
</a>

## Introduction

**ClusterCreator** automates the creation and maintenance of fully functional Kubernetes (K8S) clusters of any size on Proxmox. Leveraging Terraform/OpenTofu and Ansible, it facilitates complex setups, including decoupled etcd clusters, diverse worker node configurations, and optional integration with Unifi networks and VLANs.

Having a virtualized K8S cluster allows you to not only simulate a cloud environment but also scale and customize your cluster to your needs—adding or removing nodes and disks, managing backups and snapshots of the virtual machine disks, customizing node class types, and controlling state.

---

## Features

- **Automated VM and VLAN Creation**: Utilize OpenTofu to create VMs and VLANs tailored to your cluster needs.
- **Kubernetes Installation and Configuration**: Ansible playbooks handle the installation of Kubernetes and essential add-ons.
- **Scalable Cluster Management**: Easily add or remove nodes, customize node classes, and manage hardware requirements.
- **Optional Unifi Network Integration**: Configure dedicated networks and VLANs with Unifi.
- **Highly Available Control Plane**: Implement HA control planes using Kube-VIP.
- **Customizable Networking**: Support for dual-stack networking (IPv4 & IPv6).
- **Dynamic Worker Classes**: Define worker nodes with varying CPU, memory, disk, and networking specifications.
- **Firewall and HA Settings**: Automatically set up firewall and high availability settings using Proxmox datacenter features.
- **Optional Minio Integration**: Configure your tofu state to be stored in S3-compatible storage.

---

## Prerequisites

Before proceeding, ensure you have the following:

- **Proxmox VE**: A running Proxmox cluster.
- **OpenTofu**: Installed on your control machine.
- **Ansible**: Installed on your control machine.
- **Access Credentials**: For Proxmox, and optionally Unifi and Minio.
- **Unifi Controller** (optional): For managing networks and VLANs.
- **Minio** (optional): For storing your tofu state.

---

## Installation

This tool was designed to run from your own computer (laptop, pc, etc). Though it can be installed on a Proxmox host, it is not recommended.

### 1. Add Proxmox Cluster User

ClusterCreator requires access to the Proxmox cluster. Execute the following commands on your Proxmox server to create a datacenter user:

#### 1. Add a Proxmox User:

```shell
pveum user add terraform@pve -comment "Terraform User"
```

#### 2. Add a Custom Role for Tofu with Required Permissions:

```shell
pveum role add TerraformRole -privs "Datastore.Allocate Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit Pool.Allocate Pool.Audit Sys.Audit Sys.Console Sys.Modify SDN.Use VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.Monitor VM.PowerMgmt User.Modify Mapping.Use"
```

#### 3. Assign the Role to the User at the Datacenter Level:

```shell
pveum acl modify / -user terraform@pve -role TerraformRole
```

#### 4. Create an API Token for the User:

```shell
pveum user token add terraform@pve provider --privsep=0
```

For additional documenation see [Proxmox API Token Authentication](https://registry.terraform.io/providers/bpg/proxmox/latest/docs#api-token-authentication).

### 2. Add a KUBECONFIG line to your .bashrc or .zshrc

Configure your `KUBECONFIG` environment variable to take in all `.yaml` and `.yml` files found in `~/.kube/`:

```bash
export KUBECONFIG=$(find ~/.kube \( -name '*.yaml' -o -name '*.yml' \) -print0 | xargs -0 echo | tr ' ' ':')
```

**Tip**: Add the export command to your shell's configuration file (`~/.bashrc` or `~/.zshrc`) for persistence, then start a new shell.

Use tools like `kubectx` or `kubie` or `ccr ctx` (configured below) to switch between contexts.

### 3. Setup a `ccr` alias

As a shortcut for cluster management using this tool, you should link the `clustercreator.sh` script to `ccr` so that you can use the tool while in other directories. It also sets up a configuration file needed for the bash scripts to function.

```shell
./clustercreator.sh setup-ccr
```

**NOTE: Most of the following commands have verbose `--help` output. Use it to find information omitted from the README for brevity.**

### 4. Configure Additional Providers (optional)

You can enable the Unifi provider to enable your Unifi controller to make dedicated VLANs for your cluster, allowing you to achieve network isolation if desired.

You can enable the Minio provider to store your tofu/terraform state in S3 instead of your local computer. This is recommended for your production clusters.

Use the new `ccr` command to enable the provider of your choice.

```shell
ccr toggle-providers
```

### 5. Configure Variables

The following command will show you where to set your variables. The variables you enter will be used for bash (`scripts/k8s.env`) and tofu (`terraform/variables.tf`).

```bash
ccr configure-variables
```

This will open the files for you to set
- **Template VM settings**: Temporary settings for the Template VM while it is installing packages.
- **Proxmox Information**: Information like the Proxmox url, ISO path, datastore names, etc.
  - `PROXMOX_USERNAME` can be `root` or a user that can run `sudo` commands ***without a password***.
- **Unifi Information**: (optional, needs to be toggled on first) The Unifi API url.
- **Minio Bucket, Region, and URL**: (optional, needs to be toggled on first) The minio bucket, region, and URL for storing Tofu state.

### 6. Configure Secrets

The following command will help you set up your secrets. The secrets you enter will be used for bash (`scripts/.env`) and tofu (`terraform/secrets.tf`).

```bash
ccr configure-secrets
```

This will guide you through setting
- **VM Credentials and SSH Key**: Standard linux user configuration.
- **Proxmox Credentials**: Refer to for creating API tokens.
- **Unifi Credentials**: (optional, needs to be toggled on first) Create a service account in the Unifi Controller with Site Admin permissions for the Network app.
- **Minio Access Key/Secret**: (optional, needs to be toggled on first) Create a minio access key that has read/write access to the bucket specified in `terraform/variables.tf`.

### 7. Configure Clusters

The following command will show you where to configure your cluster configurations. This file is found in tofu's (`terraform/clusters.tf`).

Remember to set the username to be your own.

```bash
ccr configure-clusters
```

**NOTE: Make sure you understand the cluster object definined at the top of `terraform/clusters.tf`. It has many options with set defaults, and many features like the PVE firewall, HA, boot on PVE startup, which are all *disabled by default***.

---

![ClusterCreator Commands](https://github.com/user-attachments/assets/8c2cde1d-2f9b-4573-83cd-e0f5ca0c8cbb)

---

## Usage

### 1. Create a VM Template

Generate a cloud-init ready VM template for Tofu.

```bash
ccr template
```

What It Does:

- Installs necessary apt packages (e.g., kubeadm, kubelet, kubectl).
- Compiles and installs packages from source (e.g., CNI plugins).
- Updates the operating system.
- Configures system settings for Kubernetes (kernel modules, sysctl).
- Sets up multipath configuration for storage systems like Longhorn.
- Supports both Ubuntu and Debian images.
- Optionally installs Nvidia drivers.

**Outcome**: A VM template that installs all required packages and configurations, ready for cloud-init.

### 2. Initialize Tofu

Initialize Tofu modules. This step is required only once (and after toggling a providers)

```bash
ccr tofu init
```

### 3. Set Cluster Context

This will create a dedicated tofu workspace for your cluster and switch your kubectl context. Use it to switch between the clusters in your `clusters.tf` file.

```bash
ccr ctx <cluster_name>
```

### 4. Create VMs with Tofu

Apply the Tofu configuration to create VMs and related resources.

```bash
ccr tofu apply
```

Functionality:

- Clones the VM template.
- Sets cloud-init parameters.
- Creates a Proxmox pool and Unifi VLAN (if configured).
- Generates `ansible/tmp/<cluster_name>/cluster_config.json` for Ansible.

### 5. Bootstrap Kubernetes

Bootstrap your Kubernetes cluster using ansible

```bash
ccr bootstrap
```

Includes:

- Optional decoupled etcd cluster setup.
- Highly available control plane with Kube-VIP.
- Cilium CNI (with optional dual-stack networking).
- MetalLB (with L2 advertisements).
- Metrics server installation.
- Node labeling and tainting.
- StorageClass configuration.
- Node preparation and joining.

### 6. Manage Kubernetes Clusters

Manage your K8s VMs using the other commands:
* `ccr add-nodes`
* `ccr drain-node`
* `ccr delete-node`
* `ccr upgrade-node`
* `ccr reset-node`
* `ccr reset-all-nodes`
* `ccr upgrade-addons`
* `ccr upgrade-k8s`
* `ccr vmctl`
* `ccr run-command`
  Each can be run with `--help` for more information on how they work, their arguments, and their flags.

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

Define custom worker classes in `clusters.tf` under the `node_classes` section of any cluster, like this.

```tf
        ...
        gpu = {
          count      = 2
          pve_nodes  = [ "Acropolis", "Parthenon" ]
          cpu_type   = "host"
          disks      = [
            { datastore = "local-btrfs", size = 20 }
          ]
          start_ip   = 190
          labels = [
            "nodeclass=gpu"
          ]
          taints  = [
            "gpu=true:NoSchedule"
          ]
          devices = [
            { mapping = "my-full-gpu-passthrough" }
          ]
        }
        ...
```
This specific example shows how to add a `gpu` class with full gpu passthrough.

[Here's a good guide](https://3os.org/infrastructure/proxmox/gpu-passthrough/gpu-passthrough-to-vm/) for setting up GPU pass-through on your PVE hosts. You'll want to make a datacenter resource mapping as well.

Custom worker classes would be done to meet specific workload requirements like:

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

    - Retry `ccr tofu apply` multiple times with larger cluster sizes.
    - Add nodes in smaller batches to distribute across the Proxmox cluster.

- **Configuration Conflicts**: Errors related to existing configurations or unresponsive VMs. \
  **Solution**:
    - Ensure no conflicting resources exist before applying.
    - Use `ccr reset-all-nodes` to reset VMs if necessary.

**Workaround**: For persistent issues, create brand-new VMs to ensure a clean environment.

---

## Final Product

### Proxmox Pools with VMs Managed by Tofu

![image](https://github.com/user-attachments/assets/8ab9ddc7-48a0-4dff-a3b6-c96aaf251a50)

### Unifi Network with VLAN Managed by Tofu

![image](https://github.com/user-attachments/assets/a6af26ca-c711-4744-8067-354d7e5152ac)

### Gamma Cluster Example in K9s

![image](https://github.com/user-attachments/assets/e8d7e2ef-c757-41cc-8765-da361bfb4a67)
