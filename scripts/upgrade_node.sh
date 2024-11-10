#!/bin/bash

usage() {
  echo "Usage: ccr upgrade-node <hostname>"
  echo ""
  echo "Upgrades the kubernetes packages to the version specified in your environment settings. It is recommended to drain the node before updating it to minimize interruptions to your workloads."
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
  "KUBERNETES_LONG_VERSION"
  "KUBERNETES_MEDIUM_VERSION"
  "KUBERNETES_SHORT_VERSION"
  "HELM_VERSION"
  "CLUSTER_NAME"
  "TARGETED_NODE"
)
check_required_vars "${required_vars[@]}"
print_env_vars "${required_vars[@]}"

cd "$REPO_PATH/ansible" || exit

echo -e "${GREEN}Updating node $TARGETED_NODE from cluster: $CLUSTER_NAME.${ENDCOLOR}"

# --------------------------- Script Start ---------------------------

ansible-playbook -u "$VM_USERNAME" generate-hosts-txt.yaml -e "cluster_name=${CLUSTER_NAME}"

ansible-playbook upgrade-node.yaml -u "$VM_USERNAME" -i "tmp/${CLUSTER_NAME}/ansible-hosts.txt" \
   --private-key "$HOME/.ssh/${NON_PASSWORD_PROTECTED_SSH_KEY}" \
   -e "node_name=$TARGETED_NODE" \
   -e "KUBERNETES_LONG_VERSION=$KUBERNETES_LONG_VERSION" \
   -e "KUBERNETES_MEDIUM_VERSION=$KUBERNETES_MEDIUM_VERSION" \
   -e "KUBERNETES_SHORT_VERSION=$KUBERNETES_SHORT_VERSION" \
   -e "HELM_VERSION=$HELM_VERSION" \
   --limit="${TARGETED_NODE}"

# ---------------------------- Script End ----------------------------

echo -e "${GREEN}DONE${ENDCOLOR}"
