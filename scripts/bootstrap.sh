#!/bin/bash

usage() {
  echo "Usage: ccr bootstrap"
  echo ""
  echo "Run a series of Ansible playbooks to bootstrap the your Kubernetes cluster"
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
trap 'echo "An error occurred. Cleaning up..."; cleanup_files "${cleanup_files[@]}"' ERR

echo -e "${GREEN}Bootstrapping Kubernetes onto cluster: $CLUSTER_NAME.${ENDCOLOR}"

# --------------------------- Script Start ---------------------------

# Prompt for confirmation
echo -e "${YELLOW}Warning: Once bootstrapped, you can't add/remove decoupled etcd nodes using this toolset.${ENDCOLOR}"
read -r -p "Are you sure you want to proceed? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "Operation canceled."
  exit 1
fi

playbooks=(
  "generate-hosts-txt.yaml"
  "trust-hosts.yaml"
  "prepare-nodes.yaml"
  "etcd-nodes-setup.yaml"
  "kubevip-setup.yaml"
  "apiserver-setup.yaml"
  "move-kubeconfig-local.yaml"
  "join-apiserver-nodes.yaml"
  "join-worker-nodes.yaml"
  "move-kubeconfig-remote.yaml"
  "conditionally-taint-control-plane.yaml"
  "cilium-setup.yaml"
  "local-storageclasses-setup.yaml"
  "metrics-server-setup.yaml"
  "label-and-taint-nodes.yaml"
  "ending-output.yaml"
)
run_playbooks "${playbooks[@]}"

echo ""
echo -e "${GREEN}Remember to remove the annotation 'storageclass.kubernetes.io/is-default-class: \"true\"' from the local-path storageclass if you choose to use something else like Longhorn, Rook, OpenEBS, etc.${ENDCOLOR}"
echo ""

# ---------------------------- Script End ----------------------------

cleanup_files "${cleanup_files[@]}"

echo -e "${GREEN}DONE${ENDCOLOR}"
