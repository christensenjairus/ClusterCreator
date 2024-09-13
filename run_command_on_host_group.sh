#!/bin/bash

# Initialize variables
GROUP_NAME="all"
COMMAND=""
CLUSTER_NAME=""

GREEN='\033[32m'
RED='\033[0;31m'
ENDCOLOR='\033[0m'

# Usage message
usage() {
    echo "Usage: $0 -g group_name -c 'command_to_run' -n cluster_name"
    echo "  -g, --group        Group name in the Ansible hosts file"
    echo "  -c, --command    Command to execute on the specified group"
    echo "  -n, --cluster-name Cluster name for the Ansible hosts file path"
    exit 1
}

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

echo -e "${GREEN}All required environment variables are set.${ENDCOLOR}"

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -g|--group) GROUP_NAME="$2"; shift ;;
        -c|--command) COMMAND="$2"; shift ;;
        -n|--cluster-name) CLUSTER_NAME="$2"; shift ;;
        *) usage ;;
    esac
    shift
done

# Validate input parameters
if [ -z "$GROUP_NAME" ] || [ -z "$COMMAND" ] || [ -z "$CLUSTER_NAME" ]; then
    echo "Error: All parameters are required."
    usage
fi

echo -e "${GREEN}Cluster: $CLUSTER_NAME${ENDCOLOR}"
echo -e "${GREEN}Group: $GROUP_NAME${ENDCOLOR}"
echo -e "${GREEN}Command: '$COMMAND${ENDCOLOR}'"

# Construct the Ansible inventory file path based on the cluster name
INVENTORY_FILE="ansible/tmp/${CLUSTER_NAME}/ansible-hosts.txt"

# Validate if the Ansible inventory file exists
if [ ! -f "$INVENTORY_FILE" ]; then
    echo -e "${RED}Error: Inventory file does not exist at $INVENTORY_FILE. Your cluster name may not be correct.${ENDCOLOR}"
    exit 2
fi

# Ansible playbook temporary file
PLAYBOOK_FILE=$(mktemp /tmp/ansible_playbook_run_command.yml)

# Create a temporary Ansible playbook
cat << EOF > $PLAYBOOK_FILE
---
- name: Execute command on specified hosts
  hosts: $GROUP_NAME
  gather_facts: false
  tasks:
    - name: Execute the command
      command: $COMMAND
      register: cmd_output
    - name: Print command output (skips when command has no output)
      debug:
        msg: "{{ cmd_output.stdout_lines }}"
      when: cmd_output.stdout_lines | length > 0
EOF

# Execute Ansible playbook
ansible-playbook -u $VM_USERNAME -i $INVENTORY_FILE $PLAYBOOK_FILE \
  --private-key "$HOME/.ssh/${NON_PASSWORD_PROTECTED_SSH_KEY}"

# Remove the temporary playbook file
rm $PLAYBOOK_FILE
