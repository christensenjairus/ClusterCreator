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

pushd ./ansible

cleanup_function() {
  rm -f \
    "tmp/${CLUSTER_NAME}/wrkr_join_command.sh" \
    "tmp/${CLUSTER_NAME}/cp_join_command.sh" \
    >&/dev/null
  popd
  echo "Cleanup complete."
}

# run ansible playbooks
ansible-playbook -i "tmp/${CLUSTER_NAME}/ansible-hosts.txt" -u $VM_USERNAME ansible-reset-cluster.yaml\
  -e "cluster_name=${CLUSTER_NAME}"

# cleanup join commands
cleanup_function