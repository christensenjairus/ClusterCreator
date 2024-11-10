#!/bin/bash

usage() {
  echo "Usage: ccr upgrade-k8s"
  echo ""
  echo "Upgrades the kubernetes control-plane api to the version specified in your environment settings."
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) usage; exit 0 ;;
        *)
          echo "Unknown parameter passed: $1"
          usage
          exit 1
          ;;
    esac
    shift
done

echo -e "${GREEN}Upgrading control-plane api to $KUBERNETES_MEDIUM_VERSION on cluster: $CLUSTER_NAME.${ENDCOLOR}"

# --------------------------- Script Start ---------------------------

playbooks=(
  "trust-hosts.yaml"
  "upgrade-k8s-cluster.yaml"
)
run_playbooks "${playbooks[@]}"

# ---------------------------- Script End ----------------------------

echo -e "${GREEN}DONE${ENDCOLOR}"
