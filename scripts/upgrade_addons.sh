#!/bin/bash

usage() {
  echo "Usage: ccr upgrade-addons"
  echo ""
  echo "Upgrades the addons (cilium, kubelet-serving-cert-approver, local-path-provisioner, metrics-server, metallb) to the versions specified in your environment settings"
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

echo -e "${GREEN}Upgrading essential apps from cluster: $CLUSTER_NAME.${ENDCOLOR}"

# --------------------------- Script Start ---------------------------

playbooks=(
  "generate-hosts-txt.yaml"
  "trust-hosts.yaml"
  "cilium-setup.yaml"
  "kubelet-csr-approver.yaml"
  "local-storageclasses-setup.yaml"
  "metrics-server-setup.yaml"
  "metallb-setup.yaml"
)
run_playbooks "-e node_name=$TARGETED_NODE -e timeout_seconds=$TIMEOUT_SECONDS" "${playbooks[@]}"

# ---------------------------- Script End ----------------------------

echo -e "${GREEN}DONE${ENDCOLOR}"
