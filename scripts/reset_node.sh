#!/bin/bash

usage() {
  echo "Usage: ccr reset-node <hostname>"
  echo ""
  echo "Removes all Kubernetes files, services, and configurations from a node. It is recommended to drain and delete the node before resetting to minimize interruptions to your workloads."
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
  "VM_USERNAME"
  "NON_PASSWORD_PROTECTED_SSH_KEY"
  "KUBERNETES_MEDIUM_VERSION"
  "CLUSTER_NAME"
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
trap 'echo "An error occurred. Cleaning up..."; cleanup_files "${cleanup_files[@]}"' ERR

cd "$REPO_PATH/ansible"

echo -e "${GREEN}Resetting Kubernetes on ${TARGETED_NODE} from cluster: $CLUSTER_NAME.${ENDCOLOR}"

# --------------------------- Script Start ---------------------------

ansible-playbook -u "$VM_USERNAME" generate-hosts-txt.yaml -e "cluster_name=${CLUSTER_NAME}"

ansible-playbook -i "tmp/${CLUSTER_NAME}/ansible-hosts.txt" -u "$VM_USERNAME" reset-playbook.yaml \
  --private-key "$HOME/.ssh/${NON_PASSWORD_PROTECTED_SSH_KEY}" \
  -e "cluster_name=${CLUSTER_NAME}" \
  --limit="${TARGETED_NODE}"

# ---------------------------- Script End ----------------------------

cleanup_files "${cleanup_files[@]}"

echo -e "${GREEN}DONE${ENDCOLOR}"
