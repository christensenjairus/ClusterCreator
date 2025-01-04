#!/bin/bash

usage() {
  echo "Usage: ccr reset-node <hostname_or_node_class>"
  echo ""
  echo "Removes all Kubernetes files, services, and configurations from a host or node class. It is recommended to drain and delete the node before resetting to minimize interruptions to your workloads."
}

TARGETED_NODE=""

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) usage; exit 0 ;;
        *)
          # treat the first positional argument as the TARGETED_NODE
          if [[ -z "$TARGETED_NODE" ]]; then
              TARGETED_NODE="$1"
          else
              echo "Unknown parameter passed: $1"
              usage
              exit 1
          fi
          ;;
    esac
    shift
done

# Required Variables
required_vars=(
  "TARGETED_NODE"
)
check_required_vars "${required_vars[@]}"
print_env_vars "${required_vars[@]}"

# Cleanup
cleanup_files=(
  "tmp/${CLUSTER_NAME}/worker_join_command.sh"
  "tmp/${CLUSTER_NAME}/control_plane_join_command.sh"
)
set -e
trap 'echo "An error occurred. Cleaning up..."; cleanup_files "${cleanup_files[@]}"' ERR INT

echo -e "${GREEN}Resetting Kubernetes on ${TARGETED_NODE} from cluster: $CLUSTER_NAME.${ENDCOLOR}"

# --------------------------- Script Start ---------------------------

playbooks=(
  "trust-hosts.yaml"
  "reset-nodes.yaml"
)
run_playbooks "--limit=${TARGETED_NODE}" "${playbooks[@]}"

# ---------------------------- Script End ----------------------------

cleanup_files "${cleanup_files[@]}"

echo -e "${GREEN}DONE${ENDCOLOR}"
