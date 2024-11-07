#!/bin/bash

# Initialize default cluster name
CLUSTER_NAME=""
ADD_NODES=false

GREEN='\033[32m'
RED='\033[0;31m'
ENDCOLOR='\033[0m'

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -n|--cluster-name) CLUSTER_NAME="$2"; shift ;;
        -a|--add-nodes) ADD_NODES=true ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

if [[ -z "$CLUSTER_NAME" ]]; then
    echo -e "${RED}Error: CLUSTER_NAME is required.${ENDCOLOR}"
    echo -e "${RED}Usage: $0 --cluster-name <CLUSTER_NAME> [-a/--add-nodes]${ENDCOLOR}"
    exit 1
fi

echo -e "${GREEN}Running ansible on cluster: $CLUSTER_NAME.${ENDCOLOR}"

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pushd "$SCRIPT_DIR" || exit

set -a # automatically export all variables
source .env
source k8s.env
set +a # stop automatically exporting

required_vars=(
  "VM_USERNAME"
  "NON_PASSWORD_PROTECTED_SSH_KEY"
  "KUBERNETES_MEDIUM_VERSION"
)

# Check if each required environment variable is set
for var in "${required_vars[@]}"; do
  if [ -z "${!var}" ]; then  # Using indirect parameter expansion to check variable by name
    echo -e "${RED}Error: Environment variable $var is not set.${ENDCOLOR}" >&2
    exit 1
  fi
done

echo "All required environment variables are set."

ansible-galaxy collection install kubernetes.core

set -e
trap 'echo "An error occurred. Cleaning up..."; cleanup_function' ERR

cd ../ansible || exit

cleanup_function() {
  rm -f \
    "tmp/${CLUSTER_NAME}/worker_join_command.sh" \
    "tmp/${CLUSTER_NAME}/control_plane_join_command.sh" \
    >&/dev/null
  popd || true
  echo "Cleanup complete."
}

ansible-playbook -u "$VM_USERNAME" generate-hosts-txt.yaml -e "cluster_name=${CLUSTER_NAME}"

# run ansible playbooks
if [ "$ADD_NODES" = true ]; then
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

echo -e "${GREEN}CLUSTER CONFIGURATION COMPLETE${ENDCOLOR}"
