#!/usr/bin/env bash

usage() {
  echo "Usage: ccr configure-networks"
  echo ""
  echo "Opens your networks configuration file found in:"
  echo " * terraform/networks.tf"
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

NETWORKS_FILE="$REPO_PATH/terraform/networks.tf"

echo -e "${GREEN}Configuring your networks file${ENDCOLOR}"

read -p "Open terraform/networks.tf for editing? (y/n): " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
  if [[ ! -f "$NETWORKS_FILE" && -f "$NETWORKS_FILE.example" ]]; then
    echo -e "${YELLOW}terraform/networks.tf not found — creating it from networks.tf.example.${ENDCOLOR}"
    cp "$NETWORKS_FILE.example" "$NETWORKS_FILE"
  fi
  if [[ -f "$NETWORKS_FILE" ]]; then
    vim "$NETWORKS_FILE"
  else
    echo -e "${RED}Error: $NETWORKS_FILE not found (and no networks.tf.example to copy from).${ENDCOLOR}"
    exit 1
  fi
fi

echo -e "${GREEN}DONE${ENDCOLOR}"