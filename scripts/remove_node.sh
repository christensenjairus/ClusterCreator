#!/bin/bash

usage() {
  echo "Usage: clustercreator.sh|ccr remove-node -n/--node <hostname> [-t/--timeout <seconds>] [-d/--delete]"
}

TARGETED_NODE=""
TIMEOUT_SECONDS=600
DELETE_NODE=false

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -n|--hostname) TARGETED_NODE="$2"; shift ;;
        -t|--timeout) TIMEOUT_SECONDS="$2"; shift ;;
        -d|--delete) DELETE_NODE=true ;;
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
  "CLUSTER_NAME"
  "TARGETED_NODE"
  "TIMEOUT_SECONDS"
  "DELETE_NODE"
)

check_required_vars "${required_vars[@]}"
print_env_vars "${required_vars[@]}"

echo -e "${GREEN}Draining node $TARGETED_NODE on cluster: $CLUSTER_NAME.${ENDCOLOR}"

ansible-galaxy collection install kubernetes.core

cd "$REPO_PATH/ansible"

ansible-playbook remove-node.yaml -u "$VM_USERNAME" -i "tmp/${CLUSTER_NAME}/ansible-hosts.txt" \
   --private-key "$HOME/.ssh/${NON_PASSWORD_PROTECTED_SSH_KEY}" \
   -e "node_name=$TARGETED_NODE" \
   -e "timeout_seconds=$TIMEOUT_SECONDS" \
   -e "delete_node=$DELETE_NODE"

cleanup_function

if [ "$DELETE_NODE" = true ]; then
  ./uninstall_k8s.sh --node "$TARGETED_NODE"
  echo -e "${GREEN}Node $TARGETED_NODE has been removed from cluster and reset.${ENDCOLOR}"
else
  echo -e "${GREEN}Node $TARGETED_NODE has been drained.${ENDCOLOR}"
fi
