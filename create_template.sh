#!/bin/bash

set -a # automatically export all variables
source .env
source k8s.env
set +a # stop automatically exporting

echo "Creating k8s template vm with id: $TEMPLATE_VM_ID"

required_vars=(
  "VM_USERNAME"
  "VM_PASSWORD"
  "PROXMOX_USERNAME"
  "PROXMOX_HOST"
  "PROXMOX_ISO_PATH"
  "PROXMOX_DATASTORE"
  "IMAGE_NAME"
  "IMAGE_LINK"
  "TIMEZONE"
  "TEMPLATE_VM_ID"
  "TEMPLATE_VM_NAME"
  "TEMPLATE_DISK_SIZE"
  "TEMPLATE_VM_GATEWAY"
  "TEMPLATE_VM_IP"
  "TEMPLATE_VM_SEARCH_DOMAIN"
  "TWO_DNS_SERVERS"
  "CONTAINERD_VERSION"
  "CNI_PLUGINS_VERSION"
  "CILIUM_CLI_VERSION"
  "HUBBLE_CLI_VERSION"
  "HELM_VERSION"
  "ETCDCTL_VERSION"
#  "VITESS_VERSION"
#  "VITESS_DOWNLOAD_FILENAME"
  "KUBERNETES_SHORT_VERSION"
  "KUBERNETES_MEDIUM_VERSION"
  "KUBERNETES_LONG_VERSION"
)

# Check if each required environment variable is set
for var in "${required_vars[@]}"; do
  if [ -z "${!var}" ]; then  # Using indirect parameter expansion to check variable by name
    echo "Error: Environment variable $var is not set." >&2
    exit 1
  fi
done

echo "All required environment variables are set."

scp -q -r ./k8s_vm_template $PROXMOX_USERNAME@$PROXMOX_HOST:
scp -q -r ./.env ./k8s.env ~/.ssh/${NON_PASSWORD_PROTECTED_SSH_KEY}.pub $PROXMOX_USERNAME@$PROXMOX_HOST:k8s_vm_template/
ssh $PROXMOX_USERNAME@$PROXMOX_HOST "cd k8s_vm_template && chmod +x ./create_template_helper.sh && ./create_template_helper.sh"
ssh $PROXMOX_USERNAME@$PROXMOX_HOST "rm -rf k8s_vm_template"
