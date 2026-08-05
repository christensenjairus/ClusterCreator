#!/usr/bin/env bash

usage() {
  echo "Usage: ccr renew-etcd-certs"
  echo ""
  echo "Renews the TLS certificates on the external etcd nodes, then reissues and"
  echo "distributes the apiserver-etcd-client certificate to every controlplane."
  echo ""
  echo "Renews on each etcd node:"
  echo "  * etcd server"
  echo "  * etcd peer"
  echo "  * etcd healthcheck-client"
  echo "And on the first etcd node only:"
  echo "  * apiserver-etcd-client  (copied out to all controlplanes)"
  echo ""
  echo "Why this is needed:"
  echo "  'kubeadm upgrade apply' renews certificates only on the node it runs on."
  echo "  It has no knowledge of external etcd members, so their certificates"
  echo "  silently expire at the kubeadm default lifetime of one year. When they do,"
  echo "  the apiservers can no longer open new etcd connections - they survive on"
  echo "  established connections and watch caches while /metrics times out, so it"
  echo "  presents as a broken metrics scrape rather than a control-plane fault."
  echo ""
  echo "Safety:"
  echo "  * etcd members are renewed and restarted ONE AT A TIME, waiting for"
  echo "    cluster health in between, so quorum is never lost."
  echo "  * The existing PKI is backed up on every node before any change."
  echo "  * Aborts if the etcd CA itself has expired (that needs a CA rotation)."
  echo ""
  echo -e "${YELLOW}Take VM backups or an etcd snapshot before running this.${ENDCOLOR}"
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

echo -e "${RED}WARNING:${ENDCOLOR} This will renew etcd TLS certificates and restart the etcd"
echo "and kube-apiserver static pods on cluster: $CLUSTER_NAME."
echo ""
echo "etcd members are restarted one at a time and cluster health is checked"
echo "between each, so quorum should be preserved. Even so, this touches the"
echo -e "datastore of your control plane. ${YELLOW}Take an etcd snapshot or VM backups first.${ENDCOLOR}"
echo ""
read -r -p "Do you understand the risks and wish to continue? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
  echo -e "${RED}Renewal aborted by the user.${ENDCOLOR}"
  exit 1
fi

set -e

echo -e "${GREEN}Renewing etcd certificates on cluster: $CLUSTER_NAME.${ENDCOLOR}"

playbooks=(
  "generate-hosts-txt.yaml"
  "trust-hosts.yaml"
  "renew-etcd-certs.yaml"
  "check-cert-expiration.yaml"
)
run_playbooks "${playbooks[@]}"

# ---------------------------- Script End ----------------------------

echo -e "${GREEN}DONE${ENDCOLOR}"
