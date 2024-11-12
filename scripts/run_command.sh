#!/bin/bash

usage() {
    echo "Usage: ccr command 'command_to_run' [<hostname_or_node_class>]"
    echo ""
    echo "Runs a command with elevated permissions on the host or node class specified. The default node class is 'all'."
}

GROUP_NAME="all"
COMMAND=""
PLAYBOOK_FILE="/tmp/ansible_playbook_run_command.yml"

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) usage; exit 0 ;;
        *)
          # Assign first argument as COMMAND if empty, second as GROUP_NAME if provided
          if [[ -z "$COMMAND" ]]; then
              COMMAND="$1"
          elif [[ "$GROUP_NAME" == "all" ]]; then
              GROUP_NAME="$1"
          else
              echo "Unknown parameter passed: $1"
              usage
              exit 1
          fi
          ;;
    esac
    shift
done

# Required variables check
required_vars=(
  "GROUP_NAME"
  "COMMAND"
)
check_required_vars "${required_vars[@]}"
print_env_vars "${required_vars[@]}"

# Cleanup
cleanup_files=(
  "$PLAYBOOK_FILE"
)
set -e
trap 'echo "An error occurred. Cleaning up..."; cleanup_files "${cleanup_files[@]}"' ERR INT

echo -e "${GREEN}Running '$COMMAND' on group '$GROUP_NAME' from cluster: $CLUSTER_NAME.${ENDCOLOR}"

# --------------------------- Script Start ---------------------------

# Create a temporary Ansible playbook
cat << EOF > "$PLAYBOOK_FILE"
---
- name: Execute command on specified hosts
  hosts: $GROUP_NAME
  gather_facts: false
  become: true
  tasks:
    - name: Execute the command
      command: $COMMAND
      register: cmd_output
    - name: Print command output (skips when command has no output)
      debug:
        msg: "{{ cmd_output.stdout_lines }}"
      when: cmd_output.stdout_lines | length > 0
EOF

playbooks=(
  "generate-hosts-txt.yaml"
  "trust-hosts.yaml"
  "$PLAYBOOK_FILE"
)
run_playbooks "${playbooks[@]}"

# ---------------------------- Script End ----------------------------

cleanup_files "${cleanup_files[@]}"

echo -e "${GREEN}DONE${ENDCOLOR}"
