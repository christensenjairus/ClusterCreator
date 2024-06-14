#!/bin/bash

ACTION=""
POOL_ID=""
TIMEOUT=300 # Default timeout value

GREEN='\033[32m'
RED='\033[0;31m'
ENDCOLOR='\033[0m'

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

# Command to be executed on Proxmox host
SSH_CMD="ssh ${PROXMOX_USERNAME}@${PROXMOX_HOST}"

# Get the list of VM IDs in the pool
VM_IDS=$(${SSH_CMD} pvesh get /pools/$POOL_ID --output-format json | jq '.members[] | select(.type == "qemu") | .vmid')

for VMID in $VM_IDS; do
    if [[ "$ACTION" == "start" ]]; then
        echo -e "${GREEN}Starting VM ID: $VMID${ENDCOLOR}"
        ${SSH_CMD} qm start $VMID --timeout $TIMEOUT &
    elif [[ "$ACTION" == "shutdown" ]]; then
        echo -e "${GREEN}Shutting down VM ID: $VMID${ENDCOLOR}"
        ${SSH_CMD} qm shutdown $VMID --timeout $TIMEOUT &
    elif [[ "$ACTION" == "stop" ]]; then
        echo -e "${GREEN}Stopping VM ID: $VMID${ENDCOLOR}"
        ${SSH_CMD} qm stop $VMID --skiplock --timeout $TIMEOUT &
    elif [[ "$ACTION" == "resume" ]]; then
        echo -e "${GREEN}Resuming VM ID: $VMID${ENDCOLOR}"
        ${SSH_CMD} qm resume $VMID &
    elif [[ "$ACTION" == "pause" ]]; then
        echo -e "${GREEN}Pausing VM ID: $VMID${ENDCOLOR}"
        ${SSH_CMD} qm suspend $VMID --todisk=0 &
    elif [[ "$ACTION" == "hibernate" ]]; then
        echo -e "${GREEN}Hibernating VM ID: $VMID${ENDCOLOR}"
        ${SSH_CMD} qm suspend $VMID --todisk=1 &
    fi
done

wait

if [[ "$ACTION" == "start" ]]; then
    echo -e "${GREEN}All VMs in pool $POOL_ID have been started.${ENDCOLOR}"
elif [[ "$ACTION" == "stop" ]]; then
    echo -e "${GREEN}All VMs in pool $POOL_ID have been stopped.${ENDCOLOR}"
fi

