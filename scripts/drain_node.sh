#!/bin/bash

usage() {
  echo "Usage: ccr drain-node <hostname> [-t/--timeout <seconds>]"
  echo ""
  echo "Cordons & drains a node of workloads. Default timeout is 600 seconds."
}

TARGETED_NODE=""
TIMEOUT_SECONDS=600

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -t|--timeout) TIMEOUT_SECONDS="$2"; shift ;;
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
  "TIMEOUT_SECONDS"
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

echo -e "${GREEN}Draining node $TARGETED_NODE on cluster: $CLUSTER_NAME.${ENDCOLOR}"

# --------------------------- Script Start ---------------------------

playbooks=(
  "generate-hosts-txt.yaml"
  "trust-hosts.yaml"
  "drain-node.yaml"
)
run_playbooks "-e node_name=$TARGETED_NODE -e timeout_seconds=$TIMEOUT_SECONDS" "${playbooks[@]}"

# ---------------------------- Script End ----------------------------

cleanup_files "${cleanup_files[@]}"

echo -e "${GREEN}DONE${ENDCOLOR}"
