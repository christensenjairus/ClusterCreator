#!/usr/bin/env bash

# Define playbooks with descriptions
declare -A playbooks=(
  ["ansible-cilium-setup.yaml"]="Redeploy Cilium CNI?"
  ["ansible-metrics-server-setup.yaml"]="Deploy Metrics Server for Kubernetes?"
  ["ansible-vertical-pod-autoscaler-setup.yaml"]="Deploy Vertical Pod Autoscaler?"
  ["ansible-cert-manager-setup.yaml"]="Deploy Cert-Manager for certificate management?"
  ["ansible-longhorn-setup.yaml"]="Deploy Longhorn for distributed storage?"
  ["ansible-ingress-nginx-setup.yaml"]="Deploy Ingress Nginx for routing?"
  ["ansible-kube-prometheus-stack-setup.yaml"]="Deploy Kube-Prometheus Stack for monitoring?"
  ["ansible-hubble-ui-setup.yaml"]="Deploy Hubble UI for network visibility?"
  ["ansible-kubernetes-dashboard-setup.yaml"]="Deploy Kubernetes Dashboard?"
  ["ansible-newrelic-setup.yaml"]="Deploy New Relic for monitoring?"
  ["ansible-groundcover-setup.yaml"]="Deploy Groundcover for coverage analysis?"
)

declare -a playbook_order=(
  "ansible-cilium-setup.yaml"
  "ansible-metrics-server-setup.yaml"
  "ansible-vertical-pod-autoscaler-setup.yaml"
  "ansible-cert-manager-setup.yaml"
  "ansible-longhorn-setup.yaml"
  "ansible-ingress-nginx-setup.yaml"
  "ansible-kube-prometheus-stack-setup.yaml"
  "ansible-hubble-ui-setup.yaml"
  "ansible-kubernetes-dashboard-setup.yaml"
  "ansible-newrelic-setup.yaml"
  "ansible-groundcover-setup.yaml"
)

# Initialize default cluster name
CLUSTER_NAME=""

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -n|--cluster-name) CLUSTER_NAME="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

if [[ -z "$CLUSTER_NAME" ]]; then
    echo "Error: CLUSTER_NAME is required."
    echo "Usage: $0 --cluster-name <CLUSTER_NAME>"
    exit 1
fi

echo "Running ansible on cluster: $CLUSTER_NAME"

set -a # automatically export all variables
source .env
source k8s.env
set +a # stop automatically exporting

required_vars=(
  "VM_USERNAME"
  "GLOBAL_CLOUDFLARE_API_KEY"
  "NEWRELIC_LICENSE_KEY"
  "INGRESS_BASIC_AUTH_USERNAME"
  "INGRESS_BASIC_AUTH_PASSWORD"
  "TIMEZONE"
  "SLACK_BOT_TOKEN"
)

# Check if each required environment variable is set
for var in "${required_vars[@]}"; do
  if [ -z "${!var}" ]; then  # Using indirect parameter expansion to check variable by name
    echo "Error: Environment variable $var is not set." >&2
    exit 1
  fi
done

echo "All required environment variables are set."

set -e
trap 'echo "An error occurred. Cleaning up..."; cleanup_function' ERR

pushd ./ansible

cleanup_function() {
  popd
  echo "Cleanup complete."
}

GREEN='\033[32m'
RED='\033[0;31m'
ENDCOLOR='\033[0m'

# Array to hold selected playbooks
declare -a selected_playbooks=()
accept_all=false

echo -e "${GREEN}Select playbooks to run. You may select y/Y for yes, a/A for run all remaining, or any other character for no. q/Q will quit. No need for <enter>.${ENDCOLOR}"

for playbook_key in "${playbook_order[@]}"; do
    description="${playbooks[$playbook_key]}"
    if ! $accept_all; then
        echo -e -n "${GREEN}${description} [y/n/a/q] ${ENDCOLOR}"
        read -r -n1 response
    fi

    if [[ "$response" =~ ^[qQ]$ ]]; then
        echo -e "\n${RED}Quitting...${ENDCOLOR}"
        exit 0
    fi

    if [[ "$response" =~ ^[aA]$ ]]; then
        accept_all=true
    fi

    if $accept_all || [[ "$response" =~ ^[yY]$ ]]; then
        echo -e -n " ${GREEN}+${ENDCOLOR}"
        selected_playbooks+=("$playbook_key")
    else
        echo -e -n " ${RED}-${ENDCOLOR}"
    fi
    echo ""  # Move to a new line

done

# Run selected playbooks
echo -e "\n${GREEN}Running selected playbooks...${ENDCOLOR}\n"
for playbook in "${selected_playbooks[@]}"; do
    echo -e "${GREEN}Running $playbook...${ENDCOLOR}"
    ansible-playbook -i "tmp/${CLUSTER_NAME}/ansible-hosts.txt" -u $VM_USERNAME $playbook \
      -e "cloudflare_global_api_key=${GLOBAL_CLOUDFLARE_API_KEY}" \
      -e "newrelic_license_key=${NEWRELIC_LICENSE_KEY}" \
      -e "ssh_hosts_file=$HOME/.ssh/known_hosts" \
      -e "ingress_basic_auth_username=${INGRESS_BASIC_AUTH_USERNAME}" \
      -e "ingress_basic_auth_password=${INGRESS_BASIC_AUTH_PASSWORD}" \
      -e "slack_bot_token=${SLACK_BOT_TOKEN}" \
      -e "timezone=${TIMEZONE}"
done

cleanup_function

echo ""
echo "CLUSTER ADDONS ADDED"