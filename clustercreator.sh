#!/usr/bin/env bash

# Variables
export GREEN='\033[32m'
export RED='\033[0;31m'
export YELLOW='\033[0;33m'
export BLUE='\033[1;34m'
export ENDCOLOR='\033[0m'
CONFIG_DIR="$HOME/.config/clustercreator"
REPO_PATH_FILE="$CONFIG_DIR/repo_path"
CLUSTER_FILE="$CONFIG_DIR/current_cluster"
ENVIRONMENT_FILE="$CONFIG_DIR/current_environment"
INSTALL_PATH="${HOME}/.local/bin/ccr"

# 1Password secret reference for the age private key used to decrypt
# secrets.sops.yaml. Override by exporting SOPS_AGE_OP_REF, or bypass 1Password
# entirely by exporting SOPS_AGE_KEY / SOPS_AGE_KEY_FILE.
export SOPS_AGE_OP_REF="${SOPS_AGE_OP_REF:-op://Private/ClusterCreator SOPS age key/notesPlain}"

# Function definitions
check_required_vars() {
  local missing_vars=0
  for var in "$@"; do
    if [ -z "${!var}" ]; then
      if [[ $0 =~ clustercreator.sh|ccr ]]; then
        echo -e "${RED}Error: Environment variable $var is not set. Please set it in your secrets and/or environment configuration.${ENDCOLOR}" >&2
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

  line_width=$((max_length + 40))
  line=$(printf "%-${line_width}s" "" | tr ' ' '-')

  echo "$line"

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

  echo "$line"
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
  local ansible_opts=(
    -i tmp/"$CLUSTER_NAME"/ansible-hosts.txt
    -u "$VM_USERNAME"
    --private-key "$HOME/.ssh/$NON_PASSWORD_PROTECTED_SSH_KEY"
  )

  # Default extra vars
  local default_extra_vars=(
    -e cluster_name="$CLUSTER_NAME"
    -e ssh_key_file="$HOME/.ssh/$NON_PASSWORD_PROTECTED_SSH_KEY"
    -e ssh_hosts_file="$HOME"/.ssh/known_hosts
    -e kubernetes_long_version="$KUBERNETES_LONG_VERSION"
    -e kubernetes_medium_version="$KUBERNETES_MEDIUM_VERSION"
    -e kubernetes_short_version="$KUBERNETES_SHORT_VERSION"
    -e cni_plugins_version="$CNI_PLUGINS_VERSION"
    -e etcd_version="$ETCD_VERSION"
    -e cilium_version="$CILIUM_VERSION"
    -e metallb_version="$METALLB_VERSION"
    -e local_path_provisioner_version="$LOCAL_PATH_PROVISIONER_VERSION"
    -e metrics_server_version="$METRICS_SERVER_VERSION"
    -e kubelet_serving_cert_approver_version="$KUBELET_SERVING_CERT_APPROVER_VERSION"
  )

  # Separate playbooks from extra_vars
  local extra_vars=()
  local playbooks=()

  # Loop through arguments
  for arg in "$@"; do
    if [[ $arg == -* ]]; then
      extra_vars+=("$arg") # Collect additional variables
    else
      playbooks+=("$arg") # Collect playbooks separately
    fi
  done

  ansible-galaxy collection install kubernetes.core

  cd "$REPO_PATH/ansible" || exit 1

  export ANSIBLE_CONFIG="./helpers/ansible.cfg"

  for playbook in "${playbooks[@]}"; do
    echo -e "${BLUE}Running playbook: $playbook${ENDCOLOR}"
    # Run ansible-playbook with options, extra vars, and playbook path
    ansible-playbook "${ansible_opts[@]}" "${default_extra_vars[@]}" "${extra_vars[@]}" "$playbook"
    if [ $? -ne 0 ]; then
      echo -e "${RED}Error: Playbook $playbook failed. Exiting.${ENDCOLOR}"
      echo -e "${BLUE}If you're having trouble diagnosing the issue, please submit an issue on GitHub!${ENDCOLOR}"
      exit 1
    fi
  done
}
export -f run_playbooks

setup-ccr() {
    if [[ $1 == "-h" || $1 == "--help" ]]; then
        echo "Usage: clustercreator.sh setup-ccr"
        echo ""
        echo "This will:"
        echo " * Link the repo's clustercreator.sh script to /usr/local/bin/ccr."
        echo " * Save this repository's location in ~/.config/clustercreator so the 'ccr' command knows where to look for scripts."
        exit 1
    fi

    # Set up the repository path
    REPO_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ "$REPO_PATH" == "${HOME}/.local/bin" ]; then
      echo -e "${RED}You should only run this using the original clustercreator.sh script${ENDCOLOR}"
      exit 1
    fi
    echo -e "${BLUE}Setting repository path to $REPO_PATH${ENDCOLOR}"
    echo "$REPO_PATH" > "$REPO_PATH_FILE"

    echo -e "${BLUE}Linking clustercreator.sh to ${INSTALL_PATH}${ENDCOLOR}"
    sudo mkdir -p "${INSTALL_PATH%/*}"
    chmod +x "${REPO_PATH}/clustercreator.sh"
    sudo unlink "${INSTALL_PATH}" 2>/dev/null || true
    sudo ln -s "${REPO_PATH}/clustercreator.sh" "${INSTALL_PATH}"
    echo ""
    echo -e "${BLUE}Installation complete.\nYou can now use 'ccr' as a command.\nEnsure that ${INSTALL_PATH%/*} is in your \$PATH.${ENDCOLOR}"
    echo ""
    ccr ctx alpha
    echo ""
    echo -e "${BLUE}Context has been set to the 'alpha' cluster to start.${ENDCOLOR}"
    echo -e "${BLUE}The default 'alpha' cluster is the simplest configuration.${ENDCOLOR}"
}

ctx() {
    if [[ -z "$1" ]]; then
        cat "$CLUSTER_FILE" 2>/dev/null || echo "No context has been set yet. Set one with 'ccr ctx <cluster_name>'."
        exit 0
    elif [[ $1 == "-h" || $1 == "--help" ]]; then
        echo "Usage: $0 ctx [<cluster_name>]"
        echo ""
        echo "Adding <cluster_name> will switch the context. Omitting it will show you the current context."
        echo ""
        echo "This will:"
        echo "  * Switch your Tofu workspace"
        echo "  * Switch your Kubernetes context using kubectx"

        exit 1
    fi
    CLUSTER_NAME="$1"
    echo "$CLUSTER_NAME" > "$CLUSTER_FILE"
    ( cd "${REPO_PATH}/terraform" && ( tofu workspace select "$CLUSTER_NAME" 2>/dev/null || tofu workspace new "$CLUSTER_NAME" ))
    kubectx "$CLUSTER_NAME" 2>/dev/null || true # will be created upon bootstrapping if it doesn't already exist.
}

env-cmd() {
    if [[ -z "$1" ]]; then
        cat "$ENVIRONMENT_FILE" 2>/dev/null || echo "No environment selected. Set one with 'ccr env <name>'."
        exit 0
    elif [[ $1 == "-h" || $1 == "--help" ]]; then
        echo "Usage: $0 env [<environment_name>]"
        echo ""
        echo "Selects the active PVE environment (e.g. us-west-1, us-central-1, citadel)."
        echo "Omitting the name shows the current environment."
        echo ""
        echo "The name must match a key under 'environments:' in secrets.sops.yaml."
        echo "This determines PROXMOX_HOST/node, the Unifi URL, and the per-environment"
        echo "secrets loaded at runtime (replacing the old comment-toggling)."
        exit 1
    fi
    echo "$1" > "$ENVIRONMENT_FILE"
    echo -e "${GREEN}Environment set to '$1'.${ENDCOLOR}"
}

# Decrypt secrets.sops.yaml for the active environment and export the values as
# shell vars (VM_USERNAME/VM_PASSWORD/PROXMOX_HOST/...) and TF_VAR_* for tofu.
# Best-effort/non-fatal: it warns and returns rather than exiting, so commands
# that don't need secrets (env, configure-secrets, setup-ccr) still work.
# Commands that DO need secrets rely on the later check_required_vars for a
# clear error if something is missing.
load_secrets() {
  local secrets_file="$REPO_PATH/secrets.sops.yaml"
  if [[ ! -f "$secrets_file" ]]; then
    echo -e "${YELLOW}Warning: $secrets_file not found. Run 'ccr configure-secrets' to create it.${ENDCOLOR}" >&2
    return 0
  fi
  if [[ ! -f "$ENVIRONMENT_FILE" ]]; then
    echo -e "${YELLOW}Warning: no environment selected. Run 'ccr env <name>' to pick one.${ENDCOLOR}" >&2
    return 0
  fi
  ENVIRONMENT="$(cat "$ENVIRONMENT_FILE")"
  export ENVIRONMENT

  # Load the age private key: prefer 1Password, fall back to SOPS_AGE_KEY_FILE.
  if [[ -z "$SOPS_AGE_KEY" && -z "$SOPS_AGE_KEY_FILE" ]]; then
    if command -v op &>/dev/null; then
      SOPS_AGE_KEY="$(op read "$SOPS_AGE_OP_REF" 2>/dev/null)" && export SOPS_AGE_KEY
    fi
    if [[ -z "$SOPS_AGE_KEY" ]]; then
      export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
    fi
  fi

  local json
  if ! json="$(sops -d --output-type json "$secrets_file" 2>/dev/null)"; then
    echo -e "${RED}Warning: failed to decrypt $secrets_file (check 1Password access or your age key).${ENDCOLOR}" >&2
    return 0
  fi

  if [[ "$(printf '%s' "$json" | yq -p json '.environments | has(env(ENVIRONMENT))')" != "true" ]]; then
    echo -e "${RED}Environment '$ENVIRONMENT' not found in secrets.sops.yaml. Available: $(printf '%s' "$json" | yq -p json '.environments | keys | join(", ")')${ENDCOLOR}" >&2
    return 0
  fi

  _sv() { printf '%s' "$json" | yq -p json "$1"; }

  # Shared (identity + global secrets).
  # NOTE: we intentionally do NOT export a shell PROXMOX_USERNAME here — that is
  # the root SSH user set in k8s.env, distinct from the Terraform provider's
  # proxmox_username (below), which is only needed as TF_VAR_*.
  VM_USERNAME="$(_sv '.shared.vm_username')"; export VM_USERNAME
  TF_VAR_vm_username="$VM_USERNAME"; export TF_VAR_vm_username
  TF_VAR_proxmox_username="$(_sv '.shared.proxmox_username')"; export TF_VAR_proxmox_username
  TF_VAR_unifi_username="$(_sv '.shared.unifi_username')"; export TF_VAR_unifi_username
  TF_VAR_minio_access_key="$(_sv '.shared.minio_access_key')"; export TF_VAR_minio_access_key
  TF_VAR_minio_secret_key="$(_sv '.shared.minio_secret_key')"; export TF_VAR_minio_secret_key
  # The s3 backend can't take sensitive TF vars, so also expose the MinIO creds
  # as the standard AWS credential env vars that the backend/AWS provider read.
  AWS_ACCESS_KEY_ID="$TF_VAR_minio_access_key"; export AWS_ACCESS_KEY_ID
  AWS_SECRET_ACCESS_KEY="$TF_VAR_minio_secret_key"; export AWS_SECRET_ACCESS_KEY
  TF_VAR_vm_ssh_key="$(printf '%s' "$json" | yq -p json -o json -I 0 '.shared.vm_ssh_keys')"; export TF_VAR_vm_ssh_key

  # Per-environment (infra targets + per-env secrets)
  PROXMOX_HOST="$(_sv '.environments[env(ENVIRONMENT)].proxmox_host')"; export PROXMOX_HOST
  TF_VAR_proxmox_host="$PROXMOX_HOST"; export TF_VAR_proxmox_host
  TF_VAR_proxmox_node="$(_sv '.environments[env(ENVIRONMENT)].proxmox_node')"; export TF_VAR_proxmox_node
  TF_VAR_unifi_api_url="$(_sv '.environments[env(ENVIRONMENT)].unifi_api_url')"; export TF_VAR_unifi_api_url
  TF_VAR_proxmox_api_token="$(_sv '.environments[env(ENVIRONMENT)].proxmox_api_token')"; export TF_VAR_proxmox_api_token
  TF_VAR_unifi_password="$(_sv '.environments[env(ENVIRONMENT)].unifi_password')"; export TF_VAR_unifi_password
  VM_PASSWORD="$(_sv '.environments[env(ENVIRONMENT)].vm_password')"; export VM_PASSWORD
  TF_VAR_vm_password="$VM_PASSWORD"; export TF_VAR_vm_password

  unset -f _sv
}

display_usage() {
    echo "Usage: clustercreator.sh|ccr <command> [options]"
    echo ""
    echo "Commands:"
    echo "  setup-ccr            Creates 'ccr' command and tells it where to look for scripts"
    echo "  ctx                  Sets the current cluster context"
    echo "  env                  Sets the active PVE environment (selects per-env secrets & host)"
    echo "  configure-variables  Opens files with variables to be used by bash, ansible, and tofu"
    echo "  configure-secrets    Guides you though setting secrets to be used by bash, ansible, and tofu"
    echo "  configure-clusters   Opens your clusters configuration file"
    echo "  configure-networks   Opens your networks configuration file"
    echo "  template             Creates a VM template for Kubernetes"
    echo "  tofu                 Executes tofu commands directly"
    echo "  bootstrap            Bootstraps Kubernetes to create a cluster"
    echo "  add-nodes            Adds un-joined nodes to the cluster"
    echo "  drain-node           Drains a node of workloads"
    echo "  delete-node          Immediately deletes the node from the Kubernetes cluster"
    echo "  upgrade-node         Upgrades a node to use the Kubernetes version specified in the environment settings"
    echo "  reset-node           Resets Kubernetes configurations for one host"
    echo "  reset-all-nodes      Resets Kubernetes configurations for all hosts"
    echo "  upgrade-addons       Upgrades the addons to the versions specified in the environment settings"
    echo "  upgrade-k8s          Upgrades the control-plane api to the version specified in the environment settings"
    echo "  vmctl                Controls VM state, including power controls and backups"
    echo "  run-command          Runs a bash command on a host or an Ansible host group"
    echo ""
    echo "Use the -h/--help flag following a command for more descriptive help output."
}

# Start script logic

# Should always be executed
required_commands=(
  "ansible-playbook"
  "ansible-galaxy"
  "ansible"
  "kubectl"
  "kubectx"
  "tofu"
  "vim"
  "sops"
  "yq"
)
check_required_commands "${required_commands[@]}"

# Load REPO_PATH variable
mkdir -p "$CONFIG_DIR" # Ensure the configuration directory exists
COMMAND="$1"
shift
if [[ "$COMMAND" != "" && "$COMMAND" != "setup-ccr" && "$COMMAND" != "-h" && "$COMMAND" != "--help" ]]; then
    # Load REPO_PATH
    if [ -f "$REPO_PATH_FILE" ]; then
        REPO_PATH=$(cat "$REPO_PATH_FILE")
        export REPO_PATH
    else
        echo -e "${RED}Repository path not set. Run './clustercreator.sh setup-ccr' to set this value.${ENDCOLOR}"
        exit 1
    fi

    # Load all other environment variables
    check_required_vars "REPO_PATH"
    set -a # automatically export all variables
    source "$REPO_PATH/scripts/.env" 2>/dev/null || true
    source "$REPO_PATH/scripts/k8s.env"
    set +a # stop automatically exporting

    # Decrypt SOPS secrets for the active environment (exports VM_*/PROXMOX_HOST/
    # TF_VAR_*). Skipped for commands that create/select those (env, configure-*).
    case "$COMMAND" in
        env|configure-secrets|configure-variables|configure-clusters|configure-networks) : ;;
        *) load_secrets ;;
    esac
fi

# Load CLUSTER_FILE variable
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
  "PROXMOX_DISK_DATASTORE"
  "PROXMOX_BACKUPS_DATASTORE"
  "IMAGE_NAME"
  "IMAGE_LINK"
  "TIMEZONE"
  "TEMPLATE_VM_ID"
  "TEMPLATE_VM_NAME"
  "TEMPLATE_DISK_SIZE"
  "TEMPLATE_VM_BRIDGE"
  "TEMPLATE_VM_GATEWAY"
  "TEMPLATE_VM_IP"
  "TEMPLATE_VM_SEARCH_DOMAIN"
  "TEMPLATE_VLAN_TAG"
  "TEMPLATE_VM_CPU"
  "TEMPLATE_VM_CPU_TYPE"
  "TEMPLATE_VM_MEM"
  "TWO_DNS_SERVERS"
  "CNI_PLUGINS_VERSION"
  "ETCD_VERSION"
  "KUBERNETES_SHORT_VERSION"
  "KUBERNETES_MEDIUM_VERSION"
  "KUBERNETES_LONG_VERSION"
  "CILIUM_VERSION"
  "KUBELET_SERVING_CERT_APPROVER_VERSION"
  "LOCAL_PATH_PROVISIONER_VERSION"
  "METRICS_SERVER_VERSION"
  "METALLB_VERSION"
  "CLUSTER_NAME"
)
# Only run check_required_vars and print_env_vars for specified commands
if [[ "$COMMAND" == "template" || \
      "$COMMAND" == "bootstrap" || \
      "$COMMAND" == "add-nodes" || \
      "$COMMAND" == "drain-node" || \
      "$COMMAND" == "delete-node" || \
      "$COMMAND" == "upgrade-node" || \
      "$COMMAND" == "reset-node" || \
      "$COMMAND" == "reset-all-nodes" || \
      "$COMMAND" == "upgrade-addons" || \
      "$COMMAND" == "upgrade-k8s" || \
      "$COMMAND" == "vmctl" || \
      "$COMMAND" == "run-command" \
    ]]; then
    check_required_vars "${required_vars[@]}"
    print_env_vars "${required_vars[@]}"
fi

# Dispatch to the appropriate script based on the command
case "$COMMAND" in
    setup-ccr)
        setup-ccr "$@"
        ;;
    ctx)
        ctx "$@"
        ;;
    env)
        env-cmd "$@"
        ;;
    configure-variables)
        ( "$REPO_PATH/scripts/configure_variables.sh" "$@" )
        ;;
    configure-secrets)
        ( "$REPO_PATH/scripts/configure_secrets.sh" "$@" )
        ;;
    configure-clusters)
        ( "$REPO_PATH/scripts/configure_clusters.sh" "$@" )
        ;;
    configure-networks)
        ( "$REPO_PATH/scripts/configure_networks.sh" "$@" )
        ;;
    template)
        ( "$REPO_PATH/scripts/template.sh" "$@" )
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
    vmctl)
        ( "$REPO_PATH/scripts/vmctl.sh" "$@")
        ;;
    run-command)
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