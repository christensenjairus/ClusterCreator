#!/usr/bin/env bash

usage() {
  echo "Usage: ccr check-certs [--warn-days <n>] [--fail-on-warn]"
  echo ""
  echo "Audits the expiration of every kubeadm-managed TLS certificate on the etcd"
  echo "and controlplane nodes. Read-only; nothing is modified."
  echo ""
  echo "Options:"
  echo "  --warn-days <n>   Warn when a certificate expires within n days (default: 30)"
  echo "  --fail-on-warn    Exit non-zero if anything is expired or inside the window"
  echo "                    (useful for cron/CI monitoring)"
  echo ""
  echo "Why this exists:"
  echo "  'kubeadm upgrade apply' renews certificates only on the node it runs on."
  echo "  With an external etcd cluster it never touches the etcd members, so their"
  echo "  server/peer/healthcheck-client certificates silently expire after one year."
  echo "  When that happens the apiservers cannot open new etcd connections and"
  echo "  /metrics times out, which looks like a broken metrics scrape."
  echo ""
  echo "Renew with 'ccr renew-etcd-certs' and/or 'ccr renew-cp-certs'."
}

WARN_DAYS="30"
FAIL_ON_WARN="false"

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) usage; exit 0 ;;
        --warn-days)
          if [[ -z "$2" || "$2" == -* ]]; then
            echo "Error: --warn-days requires a value"
            usage
            exit 1
          fi
          WARN_DAYS="$2"
          shift
          ;;
        --fail-on-warn) FAIL_ON_WARN="true" ;;
        *)
          echo "Unknown parameter passed: $1"
          usage
          exit 1
          ;;
    esac
    shift
done

if ! [[ "$WARN_DAYS" =~ ^[0-9]+$ ]]; then
  echo -e "${RED}Error: --warn-days must be a positive integer.${ENDCOLOR}"
  exit 1
fi

# Required variables check
required_vars=(
  "CLUSTER_NAME"
)
check_required_vars "${required_vars[@]}"

set -e

echo -e "${GREEN}Auditing certificate expiration on cluster: $CLUSTER_NAME (warn window: ${WARN_DAYS} days).${ENDCOLOR}"

# --------------------------- Script Start ---------------------------

playbooks=(
  "generate-hosts-txt.yaml"
  "trust-hosts.yaml"
  "check-cert-expiration.yaml"
)
# NOTE: run_playbooks splits its arguments by leading '-', so each extra var must
# be a SINGLE token ("-e key=value"). Passing "-e" and "key=value" separately
# makes it treat the value as a playbook filename.
run_playbooks "-e warn_days=${WARN_DAYS}" "-e fail_on_warn=${FAIL_ON_WARN}" "${playbooks[@]}"

# ---------------------------- Script End ----------------------------

echo -e "${GREEN}DONE${ENDCOLOR}"
