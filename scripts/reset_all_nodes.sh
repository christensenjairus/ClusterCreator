#!/bin/bash

usage() {
  echo "Usage: ccr reset-all-nodes"
  echo ""
  echo "Removes all Kubernetes files, services, and configurations from all nodes. This is useful for debugging and if you're aiming to bootstrap the cluster without creating new VMs."
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

echo -e "${GREEN}Resetting Kubernetes from all nodes from cluster: $CLUSTER_NAME.${ENDCOLOR}"

# --------------------------- Script Start ---------------------------

# Prompt for confirmation
echo -e "${YELLOW}Warning: This will destroy your current cluster.${ENDCOLOR}"
read -r -p "Are you sure you want to proceed? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "Operation canceled."
  exit 1
fi

playbooks=(
  "generate-hosts-txt.yaml"
  "trust-hosts.yaml"
  "reset-nodes.yaml"
)
run_playbooks "${playbooks[@]}"

# ---------------------------- Script End ----------------------------

cleanup_files "${cleanup_files[@]}"

echo -e "${GREEN}DONE${ENDCOLOR}"
