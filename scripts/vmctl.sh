#!/bin/bash

usage() {
    echo "Usage: ccr vmctl [start|shutdown|pause|resume|hibernate|stop|snapshot|backup] [--timeout <seconds>]"
    echo ""
    echo "Controls the states of the VMs, including power, snapshots, and backups."
    echo ""
    echo "Snapshots always include VM state, saving the memory state in addition to disk state."
    echo "Backups are always full."
}

ACTION=""
POOL_ID=""
TIMEOUT=300 # Default timeout value

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        start) ACTION="start"; ;;
        shutdown) ACTION="shutdown"; ;;
        stop) ACTION="stop"; ;;
        pause) ACTION="pause"; ;;
        resume) ACTION="resume"; ;;
        hibernate) ACTION="hibernate"; ;;
        snapshot) ACTION="snapshot"; ;;
        backup) ACTION="backup"; ;;
        -t|--timeout) TIMEOUT="$2"; shift ;; # Capture the timeout value
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown parameter passed: $1"; usage; exit 1 ;;
    esac
    shift
done

# Ensure pool name is uppercase
POOL_ID=$(echo "$CLUSTER_NAME" | tr '[:lower:]' '[:upper:]')

# Required Variables
required_vars=(
  "ACTION"
  "POOL_ID"
  "TIMEOUT"
)
check_required_vars "${required_vars[@]}"
print_env_vars "${required_vars[@]}"

echo -e "${GREEN}Performing $ACTION action on cluster: $CLUSTER_NAME.${ENDCOLOR}"

# --------------------------- Script Start ---------------------------

# Command to connect to the Proxmox host
SSH_CMD="ssh -i ~/.ssh/$NON_PASSWORD_PROTECTED_SSH_KEY ${PROXMOX_USERNAME}@${PROXMOX_HOST}"

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
            ${SSH_CMD} "sudo pvesh create /nodes/$NODE/qemu/$VMID/status/start --timeout $TIMEOUT"
        elif [[ "$ACTION" == "shutdown" ]]; then
            ${SSH_CMD} "sudo pvesh create /nodes/$NODE/qemu/$VMID/status/shutdown --timeout $TIMEOUT"
        elif [[ "$ACTION" == "stop" ]]; then
            ${SSH_CMD} "sudo pvesh create /nodes/$NODE/qemu/$VMID/status/stop --skiplock --timeout $TIMEOUT"
        elif [[ "$ACTION" == "resume" ]]; then
            ${SSH_CMD} "sudo pvesh create /nodes/$NODE/qemu/$VMID/status/resume"
        elif [[ "$ACTION" == "pause" ]]; then
            ${SSH_CMD} "sudo pvesh create /nodes/$NODE/qemu/$VMID/status/suspend --todisk=0"
        elif [[ "$ACTION" == "hibernate" ]]; then
            ${SSH_CMD} "sudo pvesh create /nodes/$NODE/qemu/$VMID/status/suspend --todisk=1"
        elif [[ "$ACTION" == "snapshot" ]]; then
            SNAPSHOT_NAME="snapshot-$(date +%Y%m%d%H%M%S)"
            ${SSH_CMD} "sudo pvesh create /nodes/$NODE/qemu/$VMID/snapshot --snapname=$SNAPSHOT_NAME --vmstate=1"
        elif [[ "$ACTION" == "backup" ]]; then
            ${SSH_CMD} "sudo pvesh create /nodes/$NODE/vzdump --vmid $VMID --mode snapshot --compress zstd --quiet 1 --storage $PROXMOX_BACKUPS_DATASTORE"
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
VM_NODES=$(${SSH_CMD} sudo pvesh get "/pools/$POOL_ID" --output-format json | jq -r '.members[] | select(.type == "qemu") | "\(.node) \(.vmid)"')

# Loop through each node and VM ID and execute the specified action with retry logic
while read -r NODE VMID; do
    echo -e "${GREEN}Attempting $ACTION on VM ID: $VMID on node: $NODE${ENDCOLOR}"
    perform_action_with_retry "$NODE" "$VMID" $ACTION &
done <<< "$VM_NODES"

wait

# ---------------------------- Script End ----------------------------

echo -e "${GREEN}DONE${ENDCOLOR}"