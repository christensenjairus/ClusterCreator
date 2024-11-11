#!/bin/bash

# Variables
export GREEN='\033[32m'
export RED='\033[0;31m'
export YELLOW='\033[0;33m'
export BLUE='\033[1;34m'
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
      if [[ $0 =~ clustercreator.sh|ccr ]]; then
        echo -e "${RED}Error: Environment variable $var is not set. Please set it in your environment configuration.${ENDCOLOR}" >&2
      else
        echo -e "${RED}Error: Environment variable $var is not set. Use --help to ensure you're using the command correctly.${ENDCOLOR}" >&2
      fi
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
          echo -e "${RED}Error: '$cmd' is required but not installed. Please install it before proceeding.${ENDCOLOR}"
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

cleanup_files() {
  # Iterate over all arguments passed to the function
  for item in "$@"; do
    if [ -e "$item" ]; then
      rm -rf "$item"  # Remove file or directory
      echo -e "${BLUE}Removed $item${ENDCOLOR}"
    fi
  done
}
export -f cleanup_files

run_playbooks() {
  local ansible_opts="-i tmp/${CLUSTER_NAME}/ansible-hosts.txt -u ${VM_USERNAME} --private-key ${HOME}/.ssh/${NON_PASSWORD_PROTECTED_SSH_KEY}"

  # Default extra vars
  local default_extra_vars="\
    -e cluster_name=${CLUSTER_NAME} \
    -e ssh_key_file=${HOME}/.ssh/${NON_PASSWORD_PROTECTED_SSH_KEY} \
    -e ssh_hosts_file=${HOME}/.ssh/known_hosts \
    -e kubernetes_long_version=${KUBERNETES_LONG_VERSION} \
    -e kubernetes_medium_version=${KUBERNETES_MEDIUM_VERSION} \
    -e kubernetes_short_version=${KUBERNETES_SHORT_VERSION} \
    -e helm_version=${HELM_VERSION} \
    -e containerd_version=${CONTAINERD_VERSION} \
    -e cni_plugins_version=${CNI_PLUGINS_VERSION} \
    -e etcd_version=${ETCD_VERSION} \
    -e cilium_cli_version=${CILIUM_CLI_VERSION} \
    -e hubble_cli_version=${HUBBLE_CLI_VERSION} \
    -e vitess_download_filename=${VITESS_DOWNLOAD_FILENAME} \
    -e vitess_version=${VITESS_VERSION} \
    -e cilium_version=${CILIUM_VERSION} \
    -e local_path_provisioner_version=${LOCAL_PATH_PROVISIONER_VERSION} \
    -e metrics_server_version=${METRICS_SERVER_VERSION}
  "

  # Separate playbooks from extra_vars
  local extra_vars=""
  local playbooks=()

  # Loop through arguments
  for arg in "$@"; do
    if [[ $arg == -* ]]; then
      extra_vars="$extra_vars $arg"  # Collect additional variables
    else
      playbooks+=("$arg")  # Collect playbooks separately
    fi
  done

  ansible-galaxy collection install kubernetes.core

  cd "$REPO_PATH/ansible" || exit 1

  for playbook in "${playbooks[@]}"; do
    echo -e "${BLUE}Running playbook: $playbook${ENDCOLOR}"
    # Run ansible-playbook with options, extra vars, and playbook path
    ansible-playbook $ansible_opts $default_extra_vars $extra_vars "$playbook"
    if [ $? -ne 0 ]; then
      echo -e "${RED}Error: Playbook $playbook failed. Exiting.${ENDCOLOR}"
      echo -e "${BLUE}If you're having trouble diagnosing the issue, please submit an issue on GitHub!${ENDCOLOR}"
      exit 1
    fi
  done
}
export -f run_playbooks

init() {
    if [[ $1 == "-h" || $1 == "--help" ]]; then
        echo "Usage: clustercreator.sh init"
        echo ""
        echo "This will:"
        echo " * Link the repo's clustercreator.sh script to /usr/local/bin/ccr."
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
    echo -e "${BLUE}Setting repository path to $REPO_PATH${ENDCOLOR}"
    echo "$REPO_PATH" > "$REPO_PATH_FILE"

    echo -e "${BLUE}Linking clustercreator.sh to ${INSTALL_PATH}${ENDCOLOR}"
    chmod +x "${REPO_PATH}/clustercreator.sh"
    sudo ln -s "${REPO_PATH}/clustercreator.sh" "${INSTALL_PATH}"
    echo -e "${BLUE}Installation complete. You can now use 'ccr' as a command.${ENDCOLOR}"

    echo -e "${BLUE}Initializing tofu...${ENDCOLOR}"
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
    kubectx "$CLUSTER_NAME" 2>/dev/null || true # will be created upon bootstrapping if it doesn't already exist.
}

display_usage() {
    echo "Usage: clustercreator.sh|ccr <command> [options]"
    echo ""
    echo "Commands:"
    echo "  init              Creates 'ccr' command, tells it where to look for scripts, and initializes tofu"
    echo "  ctx               Sets the current cluster context"
    echo "  template          Creates a VM template for Kubernetes"
    echo "  tofu              Executes tofu commands directly"
    echo "  bootstrap         Bootstraps Kubernetes to create a cluster"
    echo "  add-nodes         Adds un-joined nodes to the cluster"
    echo "  drain-node        Drains a node of workloads"
    echo "  delete-node       Immediately deletes the node from the Kubernetes cluster"
    echo "  upgrade-node      Upgrades a node to use the Kubernetes version specified in the environment settings"
    echo "  reset-node        Resets Kubernetes configurations for one host"
    echo "  reset-all-nodes   Resets Kubernetes configurations for all hosts"
    echo "  upgrade-addons    Upgrades the addons to the versions specified in the environment settings"
    echo "  upgrade-k8s       Upgrades the control-plane api to the version specified in the environment settings"
    echo "  power             Controls power for VMs"
    echo "  command           Runs a bash command on an Ansible host group"
    echo ""
    echo "Use the -h/--help flag following a command for more help."
}

# Start script logic

required_commands=(
  "ansible-playbook"
  "ansible-galaxy"
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
    # Load REPO_PATH
    if [ -f "$REPO_PATH_FILE" ]; then
        REPO_PATH=$(cat "$REPO_PATH_FILE")
        export REPO_PATH
    else
        echo -e "${RED}Repository path not set. Run 'clustercreator.sh init' to initialize.${ENDCOLOR}"
        exit 1
    fi

    # Load all other environment variables
    check_required_vars "REPO_PATH"
    set -a # automatically export all variables
    source "$REPO_PATH/scripts/.env"
    source "$REPO_PATH/scripts/k8s.env"
    set +a # stop automatically exporting
fi

# Load the current cluster context if it exists and export it
if [ -f "$CLUSTER_FILE" ]; then
    CLUSTER_NAME=$(cat "$CLUSTER_FILE")
    export CLUSTER_NAME
fi

# Display help if no command is provided
if [[ -z "$COMMAND" || "$COMMAND" == "--help" || "$COMMAND" == "-h" || "$COMMAND" == "help" ]]; then
  display_usage
  exit 0
fi

required_vars=(
  "VM_USERNAME"
  "VM_PASSWORD"
  "PROXMOX_USERNAME"
  "PROXMOX_HOST"
  "PROXMOX_ISO_PATH"
  "PROXMOX_DATASTORE"
  "IMAGE_NAME"
  "IMAGE_LINK"
  "TIMEZONE"
  "TEMPLATE_VM_ID"
  "TEMPLATE_VM_NAME"
  "TEMPLATE_DISK_SIZE"
  "TEMPLATE_VM_GATEWAY"
  "TEMPLATE_VM_IP"
  "TEMPLATE_VM_SEARCH_DOMAIN"
  "TEMPLATE_VM_CPU"
  "TEMPLATE_VM_MEM"
  "TWO_DNS_SERVERS"
  "CONTAINERD_VERSION"
  "CNI_PLUGINS_VERSION"
  "CILIUM_CLI_VERSION"
  "HUBBLE_CLI_VERSION"
  "HELM_VERSION"
  "ETCD_VERSION"
  "KUBERNETES_SHORT_VERSION"
  "KUBERNETES_MEDIUM_VERSION"
  "KUBERNETES_LONG_VERSION"
  "CILIUM_VERSION"
  "LOCAL_PATH_PROVISIONER_VERSION"
  "METRICS_SERVER_VERSION"
  "CLUSTER_NAME"
)
# Don't print out variables if -h or --help is passed or during init, ctx, and tofu
# shellcheck disable=SC2199
if [[ ! " ${@} " =~ " -h " && ! " ${@} " =~ " --help " ]]; then
  if [[ "$COMMAND" != "init" && "$COMMAND" != "ctx" && "$COMMAND" != "tofu" ]]; then
    check_required_vars "${required_vars[@]}"
    print_env_vars "${required_vars[@]}"
  fi
fi

export ANSIBLE_OPTS="-i tmp/${CLUSTER_NAME}/ansible-hosts.txt -u ${VM_USERNAME} --private-key ${HOME}/.ssh/${NON_PASSWORD_PROTECTED_SSH_KEY}"
export EXTRA_ANSIBLE_VARS="\
  -e ssh_key_file=${HOME}/.ssh/${NON_PASSWORD_PROTECTED_SSH_KEY} \
  -e ssh_hosts_file=${HOME}/.ssh/known_hosts \
  -e kubernetes_version=${KUBERNETES_MEDIUM_VERSION} \
  -e cilium_version=${CILIUM_VERSION} \
  -e local_path_provisioner_version=${LOCAL_PATH_PROVISIONER_VERSION} \
  -e metrics_server_version=${METRICS_SERVER_VERSION} \
"

# Dispatch to the appropriate script based on the command
case "$COMMAND" in
    init)
        init "$@"
        ;;
    ctx)
        ctx "$@"
        ;;
    template)
        ( "$REPO_PATH/scripts/create_template.sh" "$@" )
        ;;
    bootstrap)
        ( "$REPO_PATH/scripts/bootstrap.sh" "$@" )
        ;;
    add-nodes)
        ( "$REPO_PATH/scripts/add_nodes.sh" "$@" )
        ;;
    drain-node)
        ( "$REPO_PATH/scripts/drain_node.sh" "$@" )
        ;;
    delete-node)
        ( "$REPO_PATH/scripts/delete_node.sh" "$@" )
        ;;
    upgrade-node)
        ( "$REPO_PATH/scripts/upgrade_node.sh" "$@" )
        ;;
    reset-node)
        ( "$REPO_PATH/scripts/reset_node.sh" "$@" )
        ;;
    reset-all-nodes)
        ( "$REPO_PATH/scripts/reset_all_nodes.sh" "$@" )
        ;;
    upgrade-addons)
        ( "$REPO_PATH/scripts/upgrade_addons.sh" "$@" )
        ;;
    upgrade-k8s)
        ( "$REPO_PATH/scripts/upgrade_k8s.sh" "$@" )
        ;;
    power)
        ( "$REPO_PATH/scripts/powerctl_pool.sh" "$@")
        ;;
    command)
        ( "$REPO_PATH/scripts/run_command.sh" "$@" )
        ;;
    tofu)
        ( cd "$REPO_PATH/terraform" && tofu "$@" )
        ;;
    *)
        echo -e "${RED}Unknown command: $COMMAND${ENDCOLOR}"
        display_usage
        exit 1
        ;;
esac