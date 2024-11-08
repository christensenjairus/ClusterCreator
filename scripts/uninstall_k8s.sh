#!/bin/bash

usage() {
  echo "Usage: clustercreator.sh|ccr uninstall-k8s [-n/--node <hostname>]"
}

TARGETED_NODE="*"

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -n|--node) TARGETED_NODE="$2"; shift ;;
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
  "TARGETED_NODE"
)

check_required_vars "${required_vars[@]}"
print_env_vars "${required_vars[@]}"

cd "$REPO_PATH/ansible"

## run ansible playbooks
ansible-playbook -i "tmp/${CLUSTER_NAME}/ansible-hosts.txt" -u "$VM_USERNAME" uninstall-cluster-playbook.yaml \
  --private-key "$HOME/.ssh/${NON_PASSWORD_PROTECTED_SSH_KEY}" \
  -e "cluster_name=${CLUSTER_NAME}" \
  --limit="${TARGETED_NODE}"

# cleanup join commands
cleanup_function

echo -e "${GREEN}K8S UNINSTALL COMPLETE${ENDCOLOR}"
