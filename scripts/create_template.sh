#!/bin/bash

usage() {
  echo "Usage: clustercreator.sh|ccr template"
  echo ""
  echo "This copies vm template creation files over to your proxmox node and runs them. This downloads a vm image, edits it, allows it to turn on, then installs various packages into it before turning it off and templating it."
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown parameter passed: $1"; usage; exit 1 ;;
    esac
    shift
done

check_required_vars "REPO_PATH"
cd "$REPO_PATH/scripts"

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
  "TEMPLATE_VM_CPU"
  "TEMPLATE_VM_MEM"
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
  "CLUSTER_NAME"
)

check_required_vars "${required_vars[@]}"
print_env_vars "${required_vars[@]}"

echo -e "${GREEN}Copying relevant files to Proxmox host...${ENDCOLOR}"
set -e
ssh-copy-id -f -i "${HOME}/.ssh/${NON_PASSWORD_PROTECTED_SSH_KEY}" "$PROXMOX_USERNAME"@"$PROXMOX_HOST"
scp -q -r ./k8s_vm_template "$PROXMOX_USERNAME"@"$PROXMOX_HOST":
scp -q -r ./.env ./k8s.env "${HOME}/.ssh/${NON_PASSWORD_PROTECTED_SSH_KEY}.pub" "$PROXMOX_USERNAME"@"$PROXMOX_HOST":k8s_vm_template/
set +e

echo -e "${GREEN}Executing helper script on Proxmox host to create a k8s template vm (id: $TEMPLATE_VM_ID)${ENDCOLOR}"

ssh "$PROXMOX_USERNAME"@"$PROXMOX_HOST" "cd k8s_vm_template && chmod +x ./create_template_helper.sh && ./create_template_helper.sh"
ssh "$PROXMOX_USERNAME"@"$PROXMOX_HOST" "rm -rf k8s_vm_template"
