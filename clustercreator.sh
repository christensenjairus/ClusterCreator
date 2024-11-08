#!/bin/bash

# Variables
export GREEN='\033[32m'
export RED='\033[0;31m'
export ENDCOLOR='\033[0m'
CONFIG_DIR="$HOME/.config/clustercreator"
REPO_PATH_FILE="$CONFIG_DIR/repo_path"
CLUSTER_FILE="$CONFIG_DIR/current_cluster"
INSTALL_PATH="/usr/local/bin/ccr"

# Function definitions
check_required_vars() {
  local missing_vars=0
  for var in "$@"; do
    if [ -z "${!var}" ]; then
      echo -e "${RED}Error: Environment variable $var is not set.${ENDCOLOR}" >&2
      missing_vars=1
    fi
  done

  if [ "$missing_vars" -eq 1 ]; then
    exit 1  # Exit if any required variable is missing
  fi
}
export -f check_required_vars

check_required_commands() {
  for cmd in "$@"; do
      if ! command -v "$cmd" &> /dev/null; then
          echo "Error: '$cmd' is required but not installed. Please install it before proceeding."
          exit 1
      fi
  done
}
export -f check_required_commands

print_env_vars() {
  max_length=0

  # Find the maximum length of the variable names (to print aligned output)
  for var in "$@"; do
    if [ ${#var} -gt $max_length ]; then
      max_length=${#var}
    fi
  done

  # Print each variable with aligned output
  for var in "$@"; do
    if [ -z "${!var}" ]; then  # Using indirect parameter expansion to check variable by name
      echo -e "${RED}Error: Environment variable $var is not set.${ENDCOLOR}" >&2
      exit 1
    else
      if [ "$var" = "VM_PASSWORD" ]; then
        password_length=${#VM_PASSWORD}
        masked_password=$(printf "%${password_length}s" | tr ' ' '*') # Create a string of asterisks
        printf "%-${max_length}s = %s\n" "$var" "$masked_password"
      else
        printf "%-${max_length}s = %s\n" "$var" "${!var}"
      fi
    fi
  done
}
export -f print_env_vars

init() {
    if [[ $1 == "-h" || $1 == "--help" ]]; then
        echo "Usage: clustercreator.sh init"
        echo ""
        echo "This will:"
        echo " * Copy the repo's clustercreator.sh script to /usr/local/bin/ccr."
        echo " * Save this repository's location in ~/.config/clustercreator so the 'ccr' command knows where to look for scripts."
        echo " * Initialize tofu"
        exit 1
    fi

    # Set up the repository path
    REPO_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ "$REPO_PATH" == "/usr/local/bin" ]; then
      echo -e "${RED}You should only run this using the original clustercreator.sh script${ENDCOLOR}"
      exit 1
    fi
    echo "Setting repository path to $REPO_PATH"
    echo "$REPO_PATH" > "$REPO_PATH_FILE"

    echo "Installing clustercreator.sh to ${INSTALL_PATH}"
    sudo cp "${REPO_PATH}/clustercreator.sh" "${INSTALL_PATH}"
    sudo chmod +x "${INSTALL_PATH}"
    echo "Installation complete. You can now use 'ccr' as a command."

    echo "Initializing tofu..."
    ( cd "$REPO_PATH/terraform" && tofu init -upgrade )
}

ctx() {
    if [[ -z "$1" ]]; then
        cat "$CLUSTER_FILE"
        exit 0
    elif [[ $1 == "-h" || $1 == "--help" ]]; then
        echo "Usage: $0 ctx [<cluster_name>]"
        echo ""
        echo "Adding <cluster_name> will switch the context. Omitting it will show you the current context."
        echo ""
        echo "This will:"
        echo "  * Switch your Kubernetes context using kubectx"

        exit 1
    fi
    CLUSTER_NAME="$1"
    echo "$CLUSTER_NAME" > "$CLUSTER_FILE"
    ( cd "${REPO_PATH}/terraform" && ( tofu workspace select "$CLUSTER_NAME" 2>/dev/null || tofu workspace new "$CLUSTER_NAME" ))
    kubectx "${CLUSTER_NAME}"
}

display_usage() {
    echo "Usage: $0 <command> [options]"
    echo "Commands:"
    echo "  init                Install 'ccr', tell it where to look for scripts, and initialize tofu"
    echo "  ctx                 Set the current cluster context"
    echo "  template            Create a VM template for Kubernetes"
    echo "  tofu                Executes tofu commands directly"
    echo "  install-k8s         Install Kubernetes on the cluster"
    echo "  uninstall-k8s       Uninstall Kubernetes from the cluster"
    echo "  remove-node         Removes a node from the Kubernetes cluster"
    echo "  power               Control power for VMs"
    echo "  command             Run a bash command on an Ansible host group"
    echo ""
    echo "Use the -h/--help flag following a command for more help."
}

# Start script logic

required_commands=(
  "ansible-playbook"
  "ansible"
  "kubectl"
  "kubectx"
  "tofu"
)
check_required_commands "${required_commands[@]}"

mkdir -p "$CONFIG_DIR" # Ensure the configuration directory exists
COMMAND="$1"
shift
if [ "$COMMAND" != "init" ]; then
    if [ -f "$REPO_PATH_FILE" ]; then
        REPO_PATH=$(cat "$REPO_PATH_FILE")
        export REPO_PATH
    else
        echo "Repository path not set. Run '$0 init' to initialize."
        exit 1
    fi
fi

# Load the current cluster context if it exists and export it
if [ -f "$CLUSTER_FILE" ]; then
    CLUSTER_NAME=$(cat "$CLUSTER_FILE")
    export CLUSTER_NAME
fi

# Display help if no command is provided
if [[ -z "$COMMAND" || "$COMMAND" == "--help" || "$COMMAND" == "-h" || "$COMMAND" == "help" ]]; then
  display_usage
fi

# Dispatch to the appropriate script based on the command
case "$COMMAND" in
    shortcut)
        shortcut "$@"
        ;;
    init)
        init "$@"
        ;;
    ctx)
        ctx "$@"
        ;;
    template)
        ( "$REPO_PATH/scripts/create_template.sh" "$@" )
        ;;
    install-k8s)
        ( "$REPO_PATH/scripts/install_k8s.sh" "$@" )
        ;;
    uninstall-k8s)
        ( "$REPO_PATH/scripts/uninstall_k8s.sh" "$@" )
        ;;
    remove-node)
        ( "$REPO_PATH/scripts/remove_node.sh" "$@" )
        ;;
    power)
        ( "$REPO_PATH/scripts/powerctl_pool.sh" "$@")
        ;;
    command)
        ( "$REPO_PATH/scripts/run_command_on_host_group.sh" "$@" )
        ;;
    tofu)
        ( cd "$REPO_PATH/terraform" && tofu "$@" )
        ;;
    *)
        echo -e "Unknown command: $COMMAND \n"
        display_usage
        exit 1
        ;;
esac