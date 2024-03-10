#!/bin/bash

set -a # automatically export all variables
source .env
set +a # stop automatically exporting

required_vars=(
  "VM_USERNAME"
  "VM_PASSWORD"
  "PROXMOX_USERNAME"
  "PROXMOX_HOST"
  "PROXMOX_ISO_PATH"
  "IMAGE_NAME"
  "IMAGE_LINK"
  "TIMEZONE"
  "TEMPLATE_VM_ID"
  "TEMPLATE_VM_GATEWAY"
  "TEMPLATE_VM_IP"
  "TEMPLATE_VM_SEARCH_DOMAIN"
  "TWO_DNS_SERVERS"
)

# Check if each required environment variable is set
for var in "${required_vars[@]}"; do
  if [ -z "${!var}" ]; then  # Using indirect parameter expansion to check variable by name
    echo "Error: Environment variable $var is not set." >&2
    exit 1
  fi
done

echo "All required environment variables are set."

scp ./.env ./proxmox_scripts/create_template_helper.sh ~/.ssh/${NON_PASSWORD_PROTECTED_SSH_KEY}.pub $PROXMOX_USERNAME@$PROXMOX_HOST:
ssh $PROXMOX_USERNAME@$PROXMOX_HOST "chmod +x ./create_template_helper.sh && ./create_template_helper.sh"
ssh $PROXMOX_USERNAME@$PROXMOX_HOST "rm .env create_template_helper.sh ${NON_PASSWORD_PROTECTED_SSH_KEY}.pub"