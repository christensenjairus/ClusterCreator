#!/bin/bash

usage() {
    echo "Usage: ccr command 'command_to_run' [-g|--group group_name]"
    echo ""
    echo "Runs a command on the Ansible host group specified. The group name is the same as the node class name. The default group is 'all'."
}

GROUP_NAME="all"
COMMAND=""
PLAYBOOK_FILE=$(mktemp /tmp/ansible_playbook_run_command.yml)

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -g|--group) GROUP_NAME="$2"; shift ;;
        -h|--help) usage; exit 0 ;;
        *)
          # treat the first positional argument as COMMAND
          if [[ -z "$COMMAND" ]]; then
              COMMAND="$1"
          else
              echo "Unknown parameter passed: $1"
              usage
              exit 1
          fi
          ;;
    esac
    shift
done

# Required Variables
required_vars=(
  "VM_USERNAME"
  "NON_PASSWORD_PROTECTED_SSH_KEY"
  "CLUSTER_NAME"
  "GROUP_NAME"
  "COMMAND"
  "PLAYBOOK_FILE"
)
check_required_vars "${required_vars[@]}"
print_env_vars "${required_vars[@]}"

# Cleanup
cleanup_files=(
  "$PLAYBOOK_FILE"
)
set -e
trap 'echo "An error occurred. Cleaning up..."; cleanup_files "${cleanup_files[@]}"' ERR

cd "$REPO_PATH/ansible"

echo -e "${GREEN}Running '$COMMAND' on group '$GROUP_NAME' from cluster: $CLUSTER_NAME.${ENDCOLOR}"

# --------------------------- Script Start ---------------------------

ansible-playbook -u "$VM_USERNAME" generate-hosts-txt.yaml -e "cluster_name=${CLUSTER_NAME}"

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

ansible-playbook "$PLAYBOOK_FILE" -u "$VM_USERNAME" -i "tmp/${CLUSTER_NAME}/ansible-hosts.txt" \
  --private-key "$HOME/.ssh/${NON_PASSWORD_PROTECTED_SSH_KEY}"

# ---------------------------- Script End ----------------------------

cleanup_files "${cleanup_files[@]}"

echo -e "${GREEN}DONE${ENDCOLOR}"
