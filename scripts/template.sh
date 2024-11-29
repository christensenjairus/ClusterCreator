#!/bin/bash

usage() {
  echo "Usage: ccr template"
  echo ""
  echo "Copies vm template creation files over to your proxmox node and runs them. This downloads a vm image, edits it, allows it to turn on, then installs various packages into it before turning it off and templating it."
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown parameter passed: $1"; usage; exit 1 ;;
    esac
    shift
done

cd "$REPO_PATH/scripts"

echo -e "${GREEN}Copying relevant files to Proxmox host...${ENDCOLOR}"
set -e
ssh-copy-id -f -i "${HOME}/.ssh/${NON_PASSWORD_PROTECTED_SSH_KEY}" "$PROXMOX_USERNAME"@"$PROXMOX_HOST"
scp -q -r ./k8s_vm_template "$PROXMOX_USERNAME"@"$PROXMOX_HOST":
scp -q -r ./.env ./k8s.env "${HOME}/.ssh/${NON_PASSWORD_PROTECTED_SSH_KEY}.pub" "$PROXMOX_USERNAME"@"$PROXMOX_HOST":k8s_vm_template/
set +e

echo -e "${GREEN}Executing helper script on Proxmox host to create a k8s template vm (id: $TEMPLATE_VM_ID)${ENDCOLOR}"

ssh "$PROXMOX_USERNAME"@"$PROXMOX_HOST" "cd k8s_vm_template && chmod +x ./create_template_helper.sh && ./create_template_helper.sh"
ssh "$PROXMOX_USERNAME"@"$PROXMOX_HOST" "rm -rf k8s_vm_template"
