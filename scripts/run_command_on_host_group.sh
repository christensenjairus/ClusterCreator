#!/bin/bash

usage() {
    echo "Usage: clustercreator.sh|ccr command [-g|--group group_name] -c 'command_to_run'"
}

GROUP_NAME="all"
COMMAND=""

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -g|--group) GROUP_NAME="$2"; shift ;;
        -c|--command) COMMAND="$2"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown parameter passed: $1"; usage; exit 1 ;;
    esac
    shift
done

check_required_vars "REPO_PATH"
cd "$REPO_PATH/scripts" || exit

set -a # automatically export all variables
source .env
source k8s.env
set +a # stop automatically exporting

required_vars=(
  "VM_USERNAME"
  "NON_PASSWORD_PROTECTED_SSH_KEY"
  "CLUSTER_NAME"
  "GROUP_NAME"
  "COMMAND"
)

check_required_vars "${required_vars[@]}"
print_env_vars "${required_vars[@]}"

cd "$REPO_PATH/ansible" || exit

# Construct the Ansible inventory file path based on the cluster name
INVENTORY_FILE="tmp/${CLUSTER_NAME}/ansible-hosts.txt"

# Validate if the Ansible inventory file exists
if [ ! -f "$INVENTORY_FILE" ]; then
    echo -e "${RED}Error: Inventory file does not exist at $INVENTORY_FILE. Your cluster name may not be correct.${ENDCOLOR}"
    exit 2
fi

# Ansible playbook temporary file
PLAYBOOK_FILE=$(mktemp /tmp/ansible_playbook_run_command.yml)

# Create a temporary Ansible playbook
cat << EOF > "$PLAYBOOK_FILE"
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
ansible-playbook -u "$VM_USERNAME" -i "$INVENTORY_FILE" "$PLAYBOOK_FILE" \
  --private-key "$HOME/.ssh/${NON_PASSWORD_PROTECTED_SSH_KEY}"

# Remove the temporary playbook file
rm "$PLAYBOOK_FILE"
