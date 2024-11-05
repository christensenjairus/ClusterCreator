#!/bin/bash

GREEN='\033[32m'
RED='\033[0;31m'
ENDCOLOR='\033[0m'

set -a # automatically export all variables
source .env
source k8s.env
set +a # stop automatically exporting

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
  "ETCD_VERSION"
  "KUBERNETES_SHORT_VERSION"
  "KUBERNETES_MEDIUM_VERSION"
  "KUBERNETES_LONG_VERSION"
)

max_length=0

# Find the maximum length of the variable names (to print aligned output)
for var in "${required_vars[@]}"; do
  if [ ${#var} -gt $max_length ]; then
    max_length=${#var}
  fi
done

# Print each variable with aligned output
for var in "${required_vars[@]}"; do
  if [ -z "${!var}" ]; then  # Using indirect parameter expansion to check variable by name
    echo -e "${RED}Error: Environment variable $var is not set.${ENDCOLOR}" >&2
    exit 1
  else
    if [ "$var" = "VM_PASSWORD" ]; then
      password_length=${#VM_PASSWORD}
      masked_password=$(printf "%${password_length}s" | tr ' ' '*') # Create a string of asterisks
      printf "%-${max_length}s = %s\n" "$var" "$masked_password"
    else
      printf "%-${max_length}s = %s\n" "$var" "${!var}"
    fi
  fi
done

echo ""

echo -e "${GREEN}Copying relevant files to Proxmox host...${ENDCOLOR}"
set -e
ssh-copy-id -i "${HOME}/.ssh/${NON_PASSWORD_PROTECTED_SSH_KEY}" "$PROXMOX_USERNAME"@"$PROXMOX_HOST"
scp -q -r ./k8s_vm_template "$PROXMOX_USERNAME"@"$PROXMOX_HOST":
scp -q -r ./.env ./k8s.env "${HOME}/.ssh/${NON_PASSWORD_PROTECTED_SSH_KEY}.pub" "$PROXMOX_USERNAME"@"$PROXMOX_HOST":k8s_vm_template/
set +e

echo -e "${GREEN}Executing helper script on Proxmox host to create a k8s template vm (id: $TEMPLATE_VM_ID)${ENDCOLOR}"

ssh "$PROXMOX_USERNAME"@"$PROXMOX_HOST" "cd k8s_vm_template && chmod +x ./create_template_helper.sh && ./create_template_helper.sh"
ssh "$PROXMOX_USERNAME"@"$PROXMOX_HOST" "rm -rf k8s_vm_template"
