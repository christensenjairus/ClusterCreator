#!/bin/bash

usage() {
  echo "Usage: ccr configure-clusters"
  echo ""
  echo "Opens your clusters configuration file found in:"
  echo " * terraform/clusters.tf"
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown parameter passed: $1"; usage; exit 1 ;;
    esac
    shift
done

# Define file paths
if [[ -z "$REPO_PATH" ]]; then
  echo "Error: REPO_PATH environment variable is not set."
  exit 1
fi

CLUSTERS_FILE="$REPO_PATH/terraform/clusters.tf"

echo -e "${GREEN}Configuring your clusters file${ENDCOLOR}"

# Open k8s.env file
read -p "Open terraform/clusters.tf for editing? (y/n): " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
  if [[ -f "$CLUSTERS_FILE" ]]; then
    vim "$CLUSTERS_FILE"
  else
    echo -e "${RED}Error: $CLUSTERS_FILE not found.${ENDCOLOR}"
    exit 1
  fi
fi

echo -e "${GREEN}DONE${ENDCOLOR}"