#!/bin/bash

usage() {
  echo "Usage: ccr bootstrap"
  echo ""
  echo "Run a series of Ansible playbooks to bootstrap the your Kubernetes cluster"
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

echo -e "${GREEN}Bootstrapping Kubernetes onto cluster: $CLUSTER_NAME.${ENDCOLOR}"

# --------------------------- Script Start ---------------------------

# Prompt for confirmation
echo -e "${YELLOW}Warning: Once bootstrapped, you can't add/remove decoupled etcd nodes using this toolset.${ENDCOLOR}"
read -p "Are you sure you want to proceed? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "Operation canceled."
  exit 1
fi

ansible-galaxy collection install kubernetes.core

ansible-playbook -u "$VM_USERNAME" generate-hosts-txt.yaml -e "cluster_name=${CLUSTER_NAME}"

ansible-playbook -i "tmp/${CLUSTER_NAME}/ansible-hosts.txt" -u "$VM_USERNAME" bootstrap-cluster-playbook.yaml \
  --private-key "$HOME/.ssh/${NON_PASSWORD_PROTECTED_SSH_KEY}" \
  -e "ssh_key_file=$HOME/.ssh/${NON_PASSWORD_PROTECTED_SSH_KEY}" \
  -e "ssh_hosts_file=$HOME/.ssh/known_hosts" \
  -e "kubernetes_version=${KUBERNETES_MEDIUM_VERSION}"

echo ""
echo -e "${GREEN}Remember to remove the annotation 'storageclass.kubernetes.io/is-default-class: \"true\"' from the local-path storageclass if you choose to use something else like Longhorn, Rook, OpenEBS, etc.${ENDCOLOR}"
echo ""

# ---------------------------- Script End ----------------------------

cleanup_files "${cleanup_files[@]}"

echo -e "${GREEN}DONE${ENDCOLOR}"
