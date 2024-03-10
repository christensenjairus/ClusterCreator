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

source .env

ansible-galaxy collection install kubernetes.core

set -e
trap 'echo "An error occurred. Cleaning up..."; cleanup_function' ERR

pushd ./ansible

cleanup_function() {
  rm \
    "ansible/tmp/${CLUSTER_NAME}/wrkr_join_command.sh" \
    "ansible/tmp/${CLUSTER_NAME}/cp_join_command.sh" \
    >&/dev/null
  popd
  echo "Cleanup complete."
}

ansible-playbook -u $VM_USERNAME ansible-generate-ansible-hosts-txt.yaml -e "cluster_name=${CLUSTER_NAME}"

# run ansible playbooks
ansible-playbook -i "tmp/${CLUSTER_NAME}/ansible-hosts.txt" -u $VM_USERNAME ansible-master-playbook.yaml \
  -e "cloudflare_global_api_key=${GLOBAL_CLOUDFLARE_API_KEY}" \
  -e "ssh_key_file=$HOME/.ssh/${NON_PASSWORD_PROTECTED_SSH_KEY}" \
  -e "ssh_hosts_file=$HOME/.ssh/known_hosts"

echo "CLUSTER COMPLETE"

# cleanup join commands
cleanup_function