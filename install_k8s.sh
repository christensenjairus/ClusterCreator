#!/bin/bash

# Initialize default cluster name
CLUSTER_NAME=""

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -n|--cluster-name) CLUSTER_NAME="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

if [[ -z "$CLUSTER_NAME" ]]; then
    echo "Error: CLUSTER_NAME is required."
    echo "Usage: $0 --cluster-name <CLUSTER_NAME>"
    exit 1
fi

echo "Running ansible on cluster: $CLUSTER_NAME"

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
    echo "Error: Environment variable $var is not set." >&2
    exit 1
  fi
done

echo "All required environment variables are set."

ansible-galaxy collection install kubernetes.core

set -e
trap 'echo "An error occurred. Cleaning up..."; cleanup_function' ERR

pushd ./ansible

cleanup_function() {
  rm -f \
    "tmp/${CLUSTER_NAME}/wrkr_join_command.sh" \
    "tmp/${CLUSTER_NAME}/cp_join_command.sh" \
    >&/dev/null
  popd
  echo "Cleanup complete."
}

ansible-playbook -u $VM_USERNAME ansible-generate-ansible-hosts-txt.yaml -e "cluster_name=${CLUSTER_NAME}"

# run ansible playbooks
ansible-playbook -i "tmp/${CLUSTER_NAME}/ansible-hosts.txt" -u $VM_USERNAME ansible-master-playbook.yaml \
  -e "ssh_key_file=$HOME/.ssh/${NON_PASSWORD_PROTECTED_SSH_KEY}" \
  -e "ssh_hosts_file=$HOME/.ssh/known_hosts" \
  -e "kubernetes_version=${KUBERNETES_MEDIUM_VERSION}"

# cleanup join commands
cleanup_function

echo ""
echo "BASE CLUSTER COMPLETE"
