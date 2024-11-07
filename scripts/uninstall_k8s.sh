#!/bin/bash

# Initialize default cluster name
CLUSTER_NAME=""
SINGLE_HOSTNAME="*"

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -n|--cluster-name) CLUSTER_NAME="$2"; shift ;;
        -h|--single-hostname) SINGLE_HOSTNAME="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

if [[ -z "$CLUSTER_NAME" ]]; then
    echo "Error: CLUSTER_NAME is required."
    echo "Usage: $0 -n/--cluster-name <CLUSTER_NAME> [-h/--single-hostname <SINGLE_HOSTNAME>]"
    exit 1
fi

echo "Running ansible on cluster: $CLUSTER_NAME"

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
set -e
trap 'echo "An error occurred. Cleaning up..."; cleanup_function' ERR
pushd "$SCRIPT_DIR" || exit

source .env
source k8s.env

cd ../ansible || exit

cleanup_function() {
  rm -f \
    "tmp/${CLUSTER_NAME}/worker_join_command.sh" \
    "tmp/${CLUSTER_NAME}/control_plane_join_command.sh" \
    >&/dev/null
  popd || true
  echo "Cleanup complete."
}

## run ansible playbooks
ansible-playbook -i "tmp/${CLUSTER_NAME}/ansible-hosts.txt" -u "$VM_USERNAME" uninstall-cluster-playbook.yaml \
  --private-key "$HOME/.ssh/${NON_PASSWORD_PROTECTED_SSH_KEY}" \
  -e "cluster_name=${CLUSTER_NAME}" \
  --limit="${SINGLE_HOSTNAME}"

# cleanup join commands
cleanup_function
