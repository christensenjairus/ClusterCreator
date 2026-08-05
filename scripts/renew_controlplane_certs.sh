#!/usr/bin/env bash

usage() {
  echo "Usage: ccr renew-cp-certs"
  echo ""
  echo "Renews the kubeadm-managed certificates on the controlplane nodes and"
  echo "restarts the control-plane static pods to pick them up."
  echo ""
  echo "Renews:"
  echo "  * apiserver"
  echo "  * apiserver-kubelet-client"
  echo "  * front-proxy-client"
  echo "  * admin.conf / controller-manager.conf / scheduler.conf"
  echo ""
  echo "When etcd is EXTERNAL, apiserver-etcd-client is intentionally skipped here:"
  echo "the controlplanes hold etcd/ca.crt but not etcd/ca.key, so they cannot sign"
  echo "against the etcd CA. Use 'ccr renew-etcd-certs' for that certificate."
  echo ""
  echo "Note: 'kubeadm upgrade apply' already renews these as a side effect, so you"
  echo "normally only need this if you are not upgrading and the one-year clock is"
  echo "running out. Check with 'ccr check-certs'."
  echo ""
  echo -e "${YELLOW}Take VM backups before running this.${ENDCOLOR}"
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

# Required variables check
required_vars=(
  "CLUSTER_NAME"
)
check_required_vars "${required_vars[@]}"

# --------------------------- Script Start ---------------------------

echo -e "${RED}WARNING:${ENDCOLOR} This will renew controlplane certificates and restart the"
echo "kube-apiserver, kube-controller-manager and kube-scheduler static pods on"
echo "cluster: $CLUSTER_NAME."
echo ""
echo "Nodes are processed one at a time and each apiserver is health-checked"
echo -e "before moving on. ${YELLOW}Take VM backups first.${ENDCOLOR}"
echo ""
echo "Afterward your local kubeconfig may still hold the old client certificate;"
echo "refresh it from /etc/kubernetes/admin.conf if you get auth errors."
echo ""
read -r -p "Do you understand the risks and wish to continue? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
  echo -e "${RED}Renewal aborted by the user.${ENDCOLOR}"
  exit 1
fi

set -e

echo -e "${GREEN}Renewing controlplane certificates on cluster: $CLUSTER_NAME.${ENDCOLOR}"

playbooks=(
  "generate-hosts-txt.yaml"
  "trust-hosts.yaml"
  "renew-controlplane-certs.yaml"
  "check-cert-expiration.yaml"
)
run_playbooks "${playbooks[@]}"

# ---------------------------- Script End ----------------------------

echo -e "${GREEN}DONE${ENDCOLOR}"
