#!/bin/bash

usage() {
  echo "Usage: ccr add-nodes"
  echo ""
  echo "Run a series of Ansible playbooks to add all existing un-joined nodes to the Kubernetes cluster"
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown parameter passed: $1"; usage; exit 1 ;;
    esac
    shift
done

# Cleanup
cleanup_files=(
  "tmp/${CLUSTER_NAME}/worker_join_command.sh"
  "tmp/${CLUSTER_NAME}/control_plane_join_command.sh"
)
set -e
trap 'echo "An error occurred. Cleaning up..."; cleanup_files "${cleanup_files[@]}"' ERR INT

echo -e "${GREEN}Adding nodes to cluster: $CLUSTER_NAME.${ENDCOLOR}"

# --------------------------- Script Start ---------------------------

playbooks=(
  "generate-hosts-txt.yaml"
  "trust-hosts.yaml"
  "prepare-nodes.yaml"
  "kubevip-setup.yaml"
  "get-join-commands.yaml"
  "join-controlplane-nodes.yaml"
  "join-worker-nodes.yaml"
  "move-kubeconfig-remote.yaml"
  "conditionally-taint-controlplane.yaml"
  "etcd-encryption.yaml"
  "label-and-taint-nodes.yaml"
  "ending-output.yaml"
)
run_playbooks "${playbooks[@]}"

# ---------------------------- Script End ----------------------------

cleanup_files "${cleanup_files[@]}"

echo -e "${GREEN}DONE${ENDCOLOR}"
