#!/bin/bash

usage() {
  echo "Usage: clustercreator.sh|ccr install-k8s [--init]"
  echo ""
  echo "This will run a series of Ansible playbooks to setup your k8s cluster. Add the --init flag for initial bootstrapping."
}

INIT=false

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --init) INIT=true ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown parameter passed: $1"; usage; exit 1 ;;
    esac
    shift
done

set -e
trap 'echo "An error occurred. Cleaning up..."; cleanup_function' ERR
cleanup_function() {
  rm -f \
    "tmp/${CLUSTER_NAME}/worker_join_command.sh" \
    "tmp/${CLUSTER_NAME}/control_plane_join_command.sh" \
    >&/dev/null
}

check_required_vars "REPO_PATH"
cd "$REPO_PATH/scripts"

set -a # automatically export all variables
source .env
source k8s.env
set +a # stop automatically exporting

required_vars=(
  "VM_USERNAME"
  "NON_PASSWORD_PROTECTED_SSH_KEY"
  "KUBERNETES_MEDIUM_VERSION"
  "CLUSTER_NAME"
  "INIT"
)

check_required_vars "${required_vars[@]}"
print_env_vars "${required_vars[@]}"

ansible-galaxy collection install kubernetes.core

cd "$REPO_PATH/ansible"

# run ansible playbooks
ansible-playbook -u "$VM_USERNAME" generate-hosts-txt.yaml -e "cluster_name=${CLUSTER_NAME}"

if [ "$INIT" == false ]; then
  echo -e "${GREEN}Running post cluster creation playbook...${ENDCOLOR}"
  ansible-playbook -i "tmp/${CLUSTER_NAME}/ansible-hosts.txt" -u "$VM_USERNAME" add-nodes-playbook.yaml \
    --private-key "$HOME/.ssh/${NON_PASSWORD_PROTECTED_SSH_KEY}" \
    -e "ssh_key_file=$HOME/.ssh/${NON_PASSWORD_PROTECTED_SSH_KEY}" \
    -e "ssh_hosts_file=$HOME/.ssh/known_hosts" \
    -e "kubernetes_version=${KUBERNETES_MEDIUM_VERSION}"
else
  echo -e "${GREEN}Running init cluster creation playbook...${ENDCOLOR}"
  ansible-playbook -i "tmp/${CLUSTER_NAME}/ansible-hosts.txt" -u "$VM_USERNAME" init-cluster-playbook.yaml \
    --private-key "$HOME/.ssh/${NON_PASSWORD_PROTECTED_SSH_KEY}" \
    -e "ssh_key_file=$HOME/.ssh/${NON_PASSWORD_PROTECTED_SSH_KEY}" \
    -e "ssh_hosts_file=$HOME/.ssh/known_hosts" \
    -e "kubernetes_version=${KUBERNETES_MEDIUM_VERSION}"

  echo ""
  echo -e "${GREEN}Remember to remove the annotation 'storageclass.kubernetes.io/is-default-class: \"true\"' from the local-path storageclass if you choose to use something else like Longhorn, Rook, OpenEBS, etc.${ENDCOLOR}"
  echo ""
fi

# cleanup join commands
cleanup_function

echo -e "${GREEN}K8S INSTALL COMPLETE${ENDCOLOR}"
