#!/bin/bash

# Initialize default values
CLUSTER_NAME=""
NODE_HOSTNAME=""
TIMEOUT_SECONDS=600
DELETE_NODE=false

GREEN='\033[0;32m'
RED='\033[0;31m'
ENDCOLOR='\033[0m'

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -n|--cluster-name) CLUSTER_NAME="$2"; shift ;;
        -h|--hostname) NODE_HOSTNAME="$2"; shift ;;
        -t|--timeout) TIMEOUT_SECONDS="$2"; shift ;;
        -d|--delete) DELETE_NODE=true ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

set -a # automatically export all variables
source .env
source k8s.env
set +a # stop automatically exporting

required_vars=(
  "VM_USERNAME"
)

# Check if each required environment variable is set
for var in "${required_vars[@]}"; do
  if [ -z "${!var}" ]; then  # Using indirect parameter expansion to check variable by name
    echo -e "${RED}Error: Environment variable $var is not set.${ENDCOLOR}" >&2
    exit 1
  fi
done

echo "All required environment variables are set."

# Validate required parameters
if [[ -z "$CLUSTER_NAME" || -z "$NODE_HOSTNAME" || -z "$TIMEOUT_SECONDS" ]]; then
    echo -e "${RED}Error: Cluster name, hostname, and timeout are required.${ENDCOLOR}"
    echo -e "${RED}Usage: $0 -n/--cluster-name <CLUSTER_NAME> -h/--hostname <NODE_HOSTNAME> -t/--timeout <TIMEOUT_SECONDS> [-d/--delete]${ENDCOLOR}"
    exit 1
fi

echo -e "${GREEN}Draining node $NODE_HOSTNAME on cluster: $CLUSTER_NAME.${ENDCOLOR}"

ansible-galaxy collection install kubernetes.core

set -e
trap 'echo "An error occurred. Cleaning up..."; cleanup_function' ERR

pushd ./ansible || exit

cleanup_function() {
  rm -f \
    "tmp/${CLUSTER_NAME}/worker_join_command.sh" \
    "tmp/${CLUSTER_NAME}/control_plane_join_command.sh" \
    >&/dev/null
  popd || true
  echo "Cleanup complete."
}

# Execute Ansible playbook
ansible-playbook remove-node.yaml -u $VM_USERNAME -i "tmp/${CLUSTER_NAME}/ansible-hosts.txt" \
   --private-key "$HOME/.ssh/${NON_PASSWORD_PROTECTED_SSH_KEY}" \
   -e "node_name=$NODE_HOSTNAME" \
   -e "timeout_seconds=$TIMEOUT_SECONDS" \
   -e "delete_node=$DELETE_NODE"

cleanup_function

if [ "$DELETE_NODE" = true ]; then
  ./uninstall_k8s.sh --cluster-name "$CLUSTER_NAME" --single-hostname "$NODE_HOSTNAME"
  echo -e "${GREEN}Node $NODE_HOSTNAME has been removed from cluster and reset.${ENDCOLOR}"
else
  echo -e "${GREEN}Node $NODE_HOSTNAME has been drained.${ENDCOLOR}"
fi
