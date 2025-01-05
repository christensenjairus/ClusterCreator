#!/bin/bash

usage() {
  echo "Usage: ccr upgrade-k8s"
  echo ""
  echo "Upgrades the kubernetes control-plane api to the version specified in your environment settings."
  echo "This upgrades the k8s packages on Controlplane-0. Afterward, you'll want to upgrade all the other k8s nodes using 'upgrade-node'"
  echo ""
  echo "Skipping MINOR versions when upgrading is unsupported by kubeadm."
  echo ""
  echo -e "Major version upgrades are tricky and oftentimes have breaking changes. This project cannot handle all of the upstream"
  echo -e "  k8s breaking changes and ${RED}we are not liable if this command breaks your cluster.${ENDCOLOR}"
  echo -e "${YELLOW}Take VM backups before upgrading${ENDCOLOR} and ${YELLOW}closely read the output of 'kubeadm upgrade plan'${ENDCOLOR} before continuing to upgrade."
  echo ""
  echo "See K8s documentation about Kubeadm Upgrade: https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade"
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

# User confirmation prompt
echo -e "${RED}WARNING:${ENDCOLOR} This script will upgrade the Kubernetes control-plane API to $KUBERNETES_MEDIUM_VERSION on cluster: $CLUSTER_NAME."
echo ""
echo -e "${YELLOW}This process may involve breaking changes and risks. Especially with major version upgrades, which can introduce complexities.${ENDCOLOR}"
echo -e "Please ensure you have taken VM backups and plan on reviewing the output of 'kubeadm upgrade plan' when it's presented to you."
echo -e "${RED}By proceeding, you acknowledge that this project is not liable for any issues arising from this upgrade.${ENDCOLOR}"
echo ""
read -p "Do you understand the risks and wish to continue? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
  echo -e "${RED}Upgrade aborted by the user.${ENDCOLOR}"
  exit 1
fi

echo -e "${GREEN}Upgrading control-plane API to $KUBERNETES_MEDIUM_VERSION on cluster: $CLUSTER_NAME.${ENDCOLOR}"

playbooks=(
  "trust-hosts.yaml"
  "upgrade-k8s-cluster.yaml"
  "etcd-encryption.yaml"
  "upgrade-apt.yaml"
)
run_playbooks "${playbooks[@]}"

# ---------------------------- Script End ----------------------------

echo -e "${GREEN}DONE${ENDCOLOR}"
