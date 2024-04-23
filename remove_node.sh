#!/bin/bash

# Initialize default values
CLUSTER_NAME=""
NODE_HOSTNAME=""
TIMEOUT_SECONDS=300
DELETE_NODE=false

GREEN='\033[0;32m'
RED='\033[0;31m'
ENDCOLOR='\033[0m'

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -c|--cluster-name) CLUSTER_NAME="$2"; shift ;;
        -h|--hostname) NODE_HOSTNAME="$2"; shift ;;
        -t|--timeout) TIMEOUT_SECONDS="$2"; shift ;;
        -d|--delete) DELETE_NODE=true ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

set -a # automatically export all variables
source .env
source k8s.env
set +a # stop automatically exporting

required_vars=(
  "VM_USERNAME"
)

# Check if each required environment variable is set
for var in "${required_vars[@]}"; do
  if [ -z "${!var}" ]; then  # Using indirect parameter expansion to check variable by name
    echo -e "${RED}Error: Environment variable $var is not set.${ENDCOLOR}" >&2
    exit 1
  fi
done

echo "All required environment variables are set."

# Validate required parameters
if [[ -z "$CLUSTER_NAME" || -z "$NODE_HOSTNAME" || -z "$TIMEOUT_SECONDS" ]]; then
    echo -e "${RED}Error: Cluster name, hostname, and timeout are required.${ENDCOLOR}"
    echo -e "${RED}Usage: $0 -c/--cluster-name <CLUSTER_NAME> -h/--hostname <NODE_HOSTNAME> -t/--timeout <TIMEOUT_SECONDS> [-d/--delete]${ENDCOLOR}"
    exit 1
fi

echo -e "${GREEN}Draining node $NODE_HOSTNAME on cluster: $CLUSTER_NAME.${ENDCOLOR}"

ansible-galaxy collection install kubernetes.core

set -e
trap 'echo "An error occurred. Cleaning up..."; cleanup_function' ERR

pushd ./ansible || exit

cleanup_function() {
  rm -f \
    "tmp/${CLUSTER_NAME}/worker_join_command.sh" \
    "tmp/${CLUSTER_NAME}/control_plane_join_command.sh" \
    >&/dev/null
  popd || true
  echo "Cleanup complete."
}

if [[ "$(hostname)" == "Jairus-MacBook-Pro.local" && "$NODE_HOSTNAME" != "*" ]]; then
  echo -e "${GREEN}Confirming this node can be deleted without data loss${ENDCOLOR}"
  ceph_cluster=$(kubectl --context "$CLUSTER_NAME" get cephcluster -n rook-ceph -o=jsonpath='{.items[*].metadata.name}')
  if [ "$ceph_cluster" == "rook-ceph" ]; then
    osd_list=$(kubectl --context "$CLUSTER_NAME" get pods -n rook-ceph --selector="topology-location-host=$NODE_HOSTNAME" -o=jsonpath='{.items[*].metadata.labels.osd}' | tr ' ' '\n' | sort -u)
    if [ -n "$osd_list" ]; then

      # ----------------------------------------------------------------------------------------------
      # Check if the Ceph cluster is healthy, retrying every 5 seconds up to 10 minutes
      timeout=600
      interval=5
      elapsed=0
      while true; do
        ceph_status=$(kubectl rook-ceph --context "$CLUSTER_NAME" ceph status)
        # removed the HEALTH_OK check because it can be healthy but have HEALTH_WARN when a daemon has recently crashed. We'll rely on the lack of --force in the osd deletion command to prevent data loss.
#        if echo "$ceph_status" | grep -q "health: HEALTH_OK" && \
        if echo "$ceph_status" | grep -q "osd: [4-9]\+ osds: [4-9]\+ up (since [0-9]\+[smhd]), [4-9]\+ in (since [0-9]\+[smhd])" && \
          echo "$ceph_status" | awk '/backfill|remapped|degraded|misplaced|inactive|incomplete|undersized/ { found=1; exit } END { if (found) exit 1; else exit 0; }'; then
          break
        fi
        elapsed=$((elapsed + interval))
        if [ $elapsed -ge $timeout ]; then
          echo -e "${RED}Ceph cluster is not healthy enough after $timeout seconds. Will not remove or destroy this node.${ENDCOLOR}"
          exit 1
        fi
        echo -e "${RED}Ceph cluster is degraded and/or does not have least 4 OSDs up and in. Checking again in $interval seconds...${ENDCOLOR}"
        sleep $interval
      done
      echo -e "${GREEN}Node can be deleted without risk of data loss. Proceeding to destroy node's ceph OSDs...${ENDCOLOR}"
      # ----------------------------------------------------------------------------------------------

      # Destroy OSDs on the node
      echo -e "${GREEN}Node has OSD ids: $osd_list${ENDCOLOR}"
      while read -r osd; do
        echo -e "${GREEN}Deleting OSD $osd${ENDCOLOR}"
        kubectl rook-ceph --context "$CLUSTER_NAME" ceph osd down osd.$osd
        kubectl rook-ceph --context "$CLUSTER_NAME" ceph osd out osd.$osd
        kubectl --context "$CLUSTER_NAME" -n rook-ceph delete deploy rook-ceph-osd-$osd
        echo -e "${GREEN}Waiting 5 seconds before purging OSD $osd...${ENDCOLOR}"
        sleep 5
        kubectl rook-ceph --context "$CLUSTER_NAME" rook purge-osd "$osd"
        kubectl rook-ceph --context "$CLUSTER_NAME" ceph auth del osd.$osd
      done <<< "$osd_list"
      echo -e "${GREEN}OSDs destroyed.${ENDCOLOR}"
      kubectl --context "$CLUSTER_NAME" -n rook-ceph rollout restart deploy rook-ceph-operator || true
      kubectl --context "$CLUSTER_NAME" -n rook-ceph delete job rook-ceph-osd-prepare-$NODE_HOSTNAME || true
      kubectl --context "$CLUSTER_NAME" -n rook-ceph delete deploy rook-ceph-osd-$osd || true
    else
      echo -e "${GREEN}No OSDs found on this node.${ENDCOLOR}"
    fi
  else
    echo -e "${GREEN}Ceph cluster not found. Skipping OSD deletion.${ENDCOLOR}"
  fi
fi

# Execute Ansible playbook
ansible-playbook remove-node.yaml -u $VM_USERNAME -i "tmp/${CLUSTER_NAME}/ansible-hosts.txt" \
   -e "node_name=$NODE_HOSTNAME" \
   -e "timeout_seconds=$TIMEOUT_SECONDS" \
   -e "delete_node=$DELETE_NODE"

cleanup_function

if [ "$DELETE_NODE" = true ]; then
  ./uninstall_k8s.sh --cluster-name "$CLUSTER_NAME" --single-hostname "$NODE_HOSTNAME"
  echo -e "${GREEN}Node $NODE_HOSTNAME has been removed from cluster and reset.${ENDCOLOR}"
else
  echo -e "${GREEN}Node $NODE_HOSTNAME has been drained.${ENDCOLOR}"
fi
