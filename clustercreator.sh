#!/bin/bash

# Define constants for configuration paths
CONFIG_DIR="$HOME/.config/clustercreator"
REPO_PATH_FILE="$CONFIG_DIR/repo_path"
CLUSTER_FILE="$CONFIG_DIR/current_cluster"

# Define the path to install this script
INSTALL_PATH="/usr/local/bin/clustercreator"

# Ensure the configuration directory exists
mkdir -p "$CONFIG_DIR"

# Check if required commands are installed
required_commands=("kubectl" "kubectx" "tofu" "ansible")
for cmd in "${required_commands[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: '$cmd' is required but not installed. Please install it before proceeding."
        exit 1
    fi
done

# Function to initialize the clustercreator script
init() {
    # Set up the repository path
    REPO_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    echo "Setting repository path to $REPO_PATH"
    echo "$REPO_PATH" > "$REPO_PATH_FILE"

    # Copy this script to /usr/local/bin for easy access
    echo "Installing clustercreator to ${INSTALL_PATH}"
    sudo cp "$0" "${INSTALL_PATH}"
    sudo chmod +x "${INSTALL_PATH}"
    echo "Installation complete. You can now use 'clustercreator' as a command."
}

# Load the repository path from the config file, unless running the `init` command
COMMAND="$1"
shift
if [ "$COMMAND" != "init" ]; then
    if [ -f "$REPO_PATH_FILE" ]; then
        REPO_PATH=$(cat "$REPO_PATH_FILE")
    else
        echo "Repository path not set. Run 'clustercreator init' to initialize."
        exit 1
    fi
fi

# Function to set the current cluster context
ctx() {
    CLUSTER_NAME="$1"
    if [ -z "$CLUSTER_NAME" ]; then
        echo "Usage: clustercreator ctx <CLUSTER_NAME>"
        exit 1
    fi
    echo "$CLUSTER_NAME" > "$CLUSTER_FILE"
    kubectx "$CLUSTER_NAME" 2>/dev/null
    (cd "$REPO_PATH/terraform" && tofu workspace select "$CLUSTER_NAME" 2>/dev/null) || (cd "$REPO_PATH/terraform" && tofu workspace new "$CLUSTER_NAME")
    echo "Cluster context set to '$CLUSTER_NAME'"
}

# Load the current cluster context if it exists
if [ -f "$CLUSTER_FILE" ]; then
    CLUSTER_NAME=$(cat "$CLUSTER_FILE")
fi

# Display help if no command is provided
if [ -z "$COMMAND" ]; then
    echo "Usage: clustercreator <command> [options]"
    echo "Commands:"
    echo "  init                Install the clustercreator script to /usr/local/bin"
    echo "  ctx <CLUSTER_NAME>  Set the current cluster context"
    echo "  create_template     Create a cloud-init ready VM template"
    echo "  init_tofu           Initialize Tofu modules"
    echo "  apply_tofu          Apply Tofu configuration to create VMs"
    echo "  install_k8s         Install Kubernetes on the cluster"
    echo "  add_nodes           Add nodes to the Kubernetes cluster"
    echo "  remove_node         Remove a node from the Kubernetes cluster"
    echo "  delete_node         Delete a node and uninstall Kubernetes"
    echo "  reset_all_hosts     Uninstall Kubernetes on the cluster"
    echo "  reset_host          Uninstall Kubernetes on a single host"
    echo "  destroy             Destroy VMs created by Tofu"
    echo "  power               Control power for VMs in a specified pool"
    echo "  run_command         Run a bash command on an Ansible host group"
    exit 1
fi

# Functions for each command
create_template() {
    "$REPO_PATH/scripts/create_template.sh"
}

init_tofu() {
    (cd "$REPO_PATH/terraform" && tofu init)
}

apply_tofu() {
    (cd "$REPO_PATH/terraform" && tofu apply)
}

install_k8s() {
    if [ -z "$CLUSTER_NAME" ]; then
        echo "No cluster context set. Run 'clustercreator ctx <CLUSTER_NAME>' first."
        exit 1
    fi
    "$REPO_PATH/scripts/install_k8s.sh" -n "$CLUSTER_NAME"
}

add_nodes() {
    "$REPO_PATH/scripts/install_k8s.sh" -n "$CLUSTER_NAME" --add-nodes
}

remove_node() {
    if [ -z "$NODE_HOSTNAME" ]; then
        echo "Please provide a node hostname with NODE_HOSTNAME=<hostname>"
        exit 1
    fi
    "$REPO_PATH/scripts/remove_node.sh" -n "$CLUSTER_NAME" -h "$NODE_HOSTNAME" -t "$TIMEOUT"
}

delete_node() {
    if [ -z "$NODE_HOSTNAME" ]; then
        echo "Please provide a node hostname with NODE_HOSTNAME=<hostname>"
        exit 1
    fi
    "$REPO_PATH/scripts/remove_node.sh" -n "$CLUSTER_NAME" -h "$NODE_HOSTNAME" -t "$TIMEOUT" --delete
}

reset_all_hosts() {
    "$REPO_PATH/scripts/uninstall_k8s.sh" -n "$CLUSTER_NAME"
}

reset_host() {
    if [ -z "$NODE_HOSTNAME" ]; then
        echo "Please provide a node hostname with NODE_HOSTNAME=<hostname>"
        exit 1
    fi
    "$REPO_PATH/scripts/uninstall_k8s.sh" -n "$CLUSTER_NAME" -h "$NODE_HOSTNAME"
}

destroy() {
    tofu destroy
}

power() {
    if [ -z "$ACTION" ]; then
        echo "Please specify an action with ACTION=<action>"
        exit 1
    fi
    "$REPO_PATH/scripts/powerctl_pool.sh" --"$ACTION" "$CLUSTER_NAME" --timeout "$TIMEOUT"
}

run_command() {
    if [ -z "$GROUP_NAME" ]; then
        echo "Please specify a group name with GROUP_NAME=<group_name>"
        exit 1
    fi
    if [ -z "$COMMAND" ]; then
        echo "Please specify a command with COMMAND='<command>'"
        exit 1
    fi
    "$REPO_PATH/scripts/run_command_on_host_group.sh" -n "$CLUSTER_NAME" -g "$GROUP_NAME" -c "$COMMAND"
}

# Execute the command
case "$COMMAND" in
    init) init "$@" ;;
    ctx) ctx "$@" ;;
    create_template) create_template "$@" ;;
    init_tofu) init_tofu "$@" ;;
    create_workspace) create_workspace "$@" ;;
    apply_tofu) apply_tofu "$@" ;;
    install_k8s) install_k8s "$@" ;;
    add_nodes) add_nodes "$@" ;;
    remove_node) remove_node "$@" ;;
    delete_node) delete_node "$@" ;;
    reset_all_hosts) reset_all_hosts "$@" ;;
    reset_host) reset_host "$@" ;;
    destroy) destroy "$@" ;;
    power) power "$@" ;;
    run_command) run_command "$@" ;;
    *) echo "Unknown command: $COMMAND"; exit 1 ;;
esac