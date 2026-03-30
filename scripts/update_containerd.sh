#!/usr/bin/env bash

usage() {
  echo "Usage: ccr update-containerd [hostname_or_node_class]"
  echo ""
  echo "Pushes containerd configuration (config.d/ and certs.d/) to cluster nodes and restarts containerd."
  echo "Nodes are updated one at a time to avoid cluster disruption."
  echo ""
  echo "Options:"
  echo "  -h, --help    Show this help message"
  echo ""
  echo "Arguments:"
  echo "  hostname_or_node_class  (optional) Limit to a specific node or node class"
}

TARGETED_NODE=""

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) usage; exit 0 ;;
        *)
          if [[ -z "$TARGETED_NODE" ]]; then
              TARGETED_NODE="$1"
          else
              echo "Unknown parameter passed: $1"
              usage
              exit 1
          fi
          ;;
    esac
    shift
done

echo -e "${GREEN}Updating containerd configuration for cluster: $CLUSTER_NAME${ENDCOLOR}"

# --------------------------- Script Start ---------------------------

# Generate inventory (runs on localhost, no limit)
run_playbooks "generate-hosts-txt.yaml"

if [[ -n "$TARGETED_NODE" ]]; then
  run_playbooks "--limit=${TARGETED_NODE}" "update-containerd.yaml"
else
  run_playbooks "update-containerd.yaml"
fi

# ---------------------------- Script End ----------------------------

echo -e "${GREEN}DONE${ENDCOLOR}"