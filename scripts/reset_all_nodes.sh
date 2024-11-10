#!/bin/bash

usage() {
  echo "Usage: ccr reset-all-nodes"
  echo ""
  echo "Removes all Kubernetes files, services, and configurations from all nodes. This is useful for debugging and if you're aiming to bootstrap the cluster without creating new VMs."
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown parameter passed: $1"; usage; exit 1 ;;
    esac
    shift
done

# Required Variables
required_vars=(
  "VM_USERNAME"
  "NON_PASSWORD_PROTECTED_SSH_KEY"
  "KUBERNETES_MEDIUM_VERSION"
  "CLUSTER_NAME"
)
check_required_vars "${required_vars[@]}"
print_env_vars "${required_vars[@]}"

# Cleanup
cleanup_files=(
  "tmp/${CLUSTER_NAME}/worker_join_command.sh"
  "tmp/${CLUSTER_NAME}/control_plane_join_command.sh"
)
set -e
trap 'echo "An error occurred. Cleaning up..."; cleanup_files "${cleanup_files[@]}"' ERR

cd "$REPO_PATH/ansible"

echo -e "${GREEN}Resetting Kubernetes from all nodes from cluster: $CLUSTER_NAME.${ENDCOLOR}"

# --------------------------- Script Start ---------------------------

# Prompt for confirmation
echo -e "${YELLOW}Warning: This will destroy your current cluster.${ENDCOLOR}"
read -p "Are you sure you want to proceed? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "Operation canceled."
  exit 1
fi

ansible-playbook -u "$VM_USERNAME" generate-hosts-txt.yaml -e "cluster_name=${CLUSTER_NAME}"

ansible-playbook -i "tmp/${CLUSTER_NAME}/ansible-hosts.txt" -u "$VM_USERNAME" reset-playbook.yaml \
  --private-key "$HOME/.ssh/${NON_PASSWORD_PROTECTED_SSH_KEY}" \
  -e "cluster_name=${CLUSTER_NAME}"

# ---------------------------- Script End ----------------------------

cleanup_files "${cleanup_files[@]}"

echo -e "${GREEN}DONE${ENDCOLOR}"
