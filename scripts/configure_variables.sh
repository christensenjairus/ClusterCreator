#!/bin/bash

usage() {
  echo "Usage: ccr configure-variables"
  echo ""
  echo "Opens files with variables found in:"
  echo " * scripts/k8s.env"
  echo " * terraform/variables.tf"
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

ENV_FILE="$REPO_PATH/scripts/k8s.env"
VARIABLES_FILE="$REPO_PATH/terraform/variables.tf"

echo -e "${GREEN}Configuring your variables files with required variables${ENDCOLOR}"

# Open k8s.env file
read -p "Open scripts/k8s.env for editing? (y/n): " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
  if [[ -f "$ENV_FILE" ]]; then
    vim "$ENV_FILE"
  else
    echo -e "${RED}Error: $ENV_FILE not found.${ENDCOLOR}"
    exit 1
  fi
fi

# Open variables.tf file
read -p "Open terraform/variables.tf for editing? (y/n): " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
  if [[ -f "$VARIABLES_FILE" ]]; then
    vim "$VARIABLES_FILE"
  else
    echo -e "${RED}Error: $VARIABLES_FILE not found.${ENDCOLOR}"
    exit 1
  fi
fi

echo -e "${GREEN}DONE${ENDCOLOR}"