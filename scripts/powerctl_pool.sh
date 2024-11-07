#!/bin/bash

ACTION=""
POOL_ID=""
TIMEOUT=300 # Default timeout value

GREEN='\033[32m'
RED='\033[0;31m'
ENDCOLOR='\033[0m'

cleanup_function() {
  popd || true
  echo "Cleanup complete."
}

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
set -e
trap 'echo "An error occurred. Cleaning up..."; cleanup_function' ERR
pushd "$SCRIPT_DIR" || exit

set -a # automatically export all variables
source .env
source k8s.env
set +a # stop automatically exporting

# Function to print usage
usage() {
    echo "Usage: $0 [--start|--shutdown|--pause|--resume|--hibernate|--stop] [--timeout TIMEOUT] POOL_ID"
    exit 1
}

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --start) ACTION="start"; ;;
        --shutdown) ACTION="shutdown"; ;;
        --stop) ACTION="stop"; ;;
        --pause) ACTION="pause"; ;;
        --resume) ACTION="resume"; ;;
        --hibernate) ACTION="hibernate"; ;;
        --timeout) TIMEOUT="$2"; shift ;; # Capture the timeout value
        *)
            if [[ -z "$POOL_ID" ]]; then
                POOL_ID="$1"
            else
                # If POOL_ID is already set and there's another argument, show usage
                usage
            fi
            ;;
    esac
    shift
done

# Ensure pool name is uppercase
POOL_ID=$(echo "$POOL_ID" | tr '[:lower:]' '[:upper:]')

echo -e "${GREEN}Action: $ACTION${ENDCOLOR}"
echo -e "${GREEN}Pool ID: $POOL_ID${ENDCOLOR}"
echo -e "${GREEN}Timeout: $TIMEOUT${ENDCOLOR}"

# Check if pool ID was provided
if [[ -z "$POOL_ID" ]]; then
    echo -e "${RED}Error: Pool ID is required.${ENDCOLOR}"
    usage
fi

# Check if an action was specified
if [[ -z "$ACTION" ]]; then
    echo -e "${RED}Error: Action is required.${ENDCOLOR}"
    usage
fi

# Check if an action was specified
if [[ -z "$TIMEOUT" ]]; then
    echo -e "${RED}Error: Timeout flag provided, but not correctly set.${ENDCOLOR}"
    usage
fi

# Command to connect to the Proxmox host
SSH_CMD="ssh ${PROXMOX_USERNAME}@${PROXMOX_HOST}"

# Maximum number of retries
MAX_RETRIES=3
RETRY_DELAY=5 # Delay in seconds before retrying

# Function to perform the action with retries
perform_action_with_retry() {
    local NODE=$1
    local VMID=$2
    local ACTION=$3
    local RETRY_COUNT=0

    until [ $RETRY_COUNT -ge $MAX_RETRIES ]; do
        if [[ "$ACTION" == "start" ]]; then
            ${SSH_CMD} "pvesh create /nodes/$NODE/qemu/$VMID/status/start --timeout $TIMEOUT"
        elif [[ "$ACTION" == "shutdown" ]]; then
            ${SSH_CMD} "pvesh create /nodes/$NODE/qemu/$VMID/status/shutdown --timeout $TIMEOUT"
        elif [[ "$ACTION" == "stop" ]]; then
            ${SSH_CMD} "pvesh create /nodes/$NODE/qemu/$VMID/status/stop --skiplock --timeout $TIMEOUT"
        elif [[ "$ACTION" == "resume" ]]; then
            ${SSH_CMD} "pvesh create /nodes/$NODE/qemu/$VMID/status/resume"
        elif [[ "$ACTION" == "pause" ]]; then
            ${SSH_CMD} "pvesh create /nodes/$NODE/qemu/$VMID/status/suspend --todisk=0"
        elif [[ "$ACTION" == "hibernate" ]]; then
            ${SSH_CMD} "pvesh create /nodes/$NODE/qemu/$VMID/status/suspend --todisk=1"
        fi

        # Check if the command succeeded
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Successfully performed $ACTION on VM ID: $VMID on node: $NODE${ENDCOLOR}"
            break
        else
            echo -e "${RED}Failed to perform $ACTION on VM ID: $VMID on node: $NODE. Retrying... ($((RETRY_COUNT + 1))/$MAX_RETRIES)${ENDCOLOR}"
            RETRY_COUNT=$((RETRY_COUNT + 1))
            sleep $RETRY_DELAY
        fi
    done

    # If all retries failed, log a message
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo -e "${RED}Failed to perform $ACTION on VM ID: $VMID on node: $NODE after $MAX_RETRIES retries.${ENDCOLOR}"
    fi
}

# Get the list of nodes and VM IDs in the pool
VM_NODES=$(${SSH_CMD} pvesh get /pools/$POOL_ID --output-format json | jq -r '.members[] | select(.type == "qemu") | "\(.node) \(.vmid)"')

# Loop through each node and VM ID and execute the specified action with retry logic
while read -r NODE VMID; do
    echo -e "${GREEN}Attempting $ACTION on VM ID: $VMID on node: $NODE${ENDCOLOR}"
    perform_action_with_retry $NODE $VMID $ACTION &
done <<< "$VM_NODES"

wait
