#!/bin/bash

usage() {
  echo "Usage: ccr upgrade-node <hostname_or_node_class>"
  echo ""
  echo "Upgrades the kubernetes & etcd packages to the version specified in your environment settings."
  echo "It is recommended to drain the node before updating it to minimize interruptions to your workloads."
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

echo -e "${GREEN}Upgrading node $TARGETED_NODE from cluster: $CLUSTER_NAME.${ENDCOLOR}"

# --------------------------- Script Start ---------------------------

playbooks=(
  "trust-hosts.yaml"
  "upgrade-source-packages.yaml"
  "upgrade-k8s-packages.yaml"
  "etcd-encryption.yaml"
  "upgrade-apt.yaml"
)
run_playbooks "--limit=${TARGETED_NODE}" "${playbooks[@]}"

# ---------------------------- Script End ----------------------------

echo -e "${GREEN}DONE${ENDCOLOR}"
