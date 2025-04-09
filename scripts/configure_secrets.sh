#!/bin/bash

usage() {
  echo "Usage: ccr configure-secrets"
  echo ""
  echo "Helps you set the secrets found in:"
  echo " * scripts/.env"
  echo " * terraform/secrets.tf"
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown parameter passed: $1"; usage; exit 1 ;;
    esac
    shift
done

ENV_FILE="$REPO_PATH/scripts/.env"
TF_FILE="$REPO_PATH/terraform/secrets.tf"
TMP_ENV_FILE="$REPO_PATH/scripts/.env.tmp"
TMP_TF_FILE="$REPO_PATH/terraform/secrets.tf.tmp"

# Cleanup
cleanup_files=(
  "$TMP_ENV_FILE"
  "$TMP_TF_FILE"
)
set -e
trap 'echo "" && cleanup_files "${cleanup_files[@]}"' EXIT

# Ensure .env and secrets.tf files exist; create if they don't
touch "$ENV_FILE" "$TF_FILE"
echo -e "${GREEN}Configuring your secrets files with required secrets${ENDCOLOR}"

# Define .env variables and descriptions
env_variables=(
    "VM_USERNAME|Enter the desired username for your VMs"
    "VM_PASSWORD|Enter the desired password for your VMs"
)

# Define secrets.tf variables and descriptions (excluding VM_USERNAME and VM_PASSWORD as they'll be auto-filled)
tf_variables=(
    "vm_ssh_key|Paste the contents of your SSH key's .pub file, for VM access"
    "proxmox_username|Enter the Proxmox username. The README guides you to use 'terraform'"
    "proxmox_api_token|Enter the Proxmox API token in the following format: 'terraform@pve!provider=<token>'. The README guides you through making this token"
#     "unifi_username|Enter the Unifi service account username. User must have 'Site Admin' permissions for the Network app"
#     "unifi_password|Enter the Unifi service account password"
#     "minio_access_key|Enter the MinIO access key"
#     "minio_secret_key|Enter the MinIO secret key"
)

# Function to prompt and save secrets
prompt_and_save_secrets() {
    local file_path="$1"
    local temp_file="$2"
    shift 2
    local variables=("$@")
    > "$temp_file" # Clear temp file

    # Load existing values and prompt for each variable
    for entry in "${variables[@]}"; do
        var_name="${entry%%|*}"
        var_description="${entry#*|}"

        # Fetch current value from the existing file, removing quotes if present
        current_value=$(grep -m 1 "^${var_name}=" "$file_path" | sed -E 's/^[^=]+=\s*"([^"]*)".*$/\1/')

        # Display prompt with existing value as default if it exists
        if [[ -n "$current_value" ]]; then
            printf "%s [%s]: " "$var_description" "$current_value"
        else
            printf "%s: " "$var_description"
        fi

        # Disable ^C display, read input, and handle EOF (Ctrl+D)
        stty -echoctl
        if ! read -e input_value; then
            exit 0
        fi
        stty echoctl

        # Set new value to either input or existing value
        new_value="${input_value:-$current_value}"
        echo "$var_name=\"$new_value\"" >> "$temp_file"
    done
}

# Create tmp .env file
prompt_and_save_secrets "$ENV_FILE" "$TMP_ENV_FILE" "${env_variables[@]}"

# Write secrets.tf header
cat << EOF > "$TMP_TF_FILE"
variable "vm_username" {
  default = "$(grep -m 1 "^VM_USERNAME=" "$TMP_ENV_FILE" | sed -E 's/^[^=]+=\s*"([^"]*)".*$/\1/')" # change me to your username
}
variable "vm_password" {
  default = "$(grep -m 1 "^VM_PASSWORD=" "$TMP_ENV_FILE" | sed -E 's/^[^=]+=\s*"([^"]*)".*$/\1/')"
}
variable "vm_ssh_key" {
  type = list(string)
  default = [
EOF

# Get current SSH keys from secrets.tf if they exist
current_keys=$(awk '/vm_ssh_key/,/^}/' "$TF_FILE" | awk '/default = \[/,/\]/' | grep -v "default = \[" | grep -v "^}" | grep -v "variable" | grep -v "^[[:space:]]*\]" | sed 's/^[[:space:]]*//' | sed 's/,$//' | sed 's/^"//' | sed 's/"$//')

# Display prompt with existing keys as default
if [[ -n "$current_keys" ]]; then
    echo -e "\nCurrent SSH keys:"
    echo "$current_keys"
    echo -e "\nEnter new SSH keys (one per line, press Ctrl+D when done, or just press Ctrl+D to keep current keys):"
else
    echo -e "\nEnter SSH keys (one per line, press Ctrl+D when done):"
fi

# Read SSH keys into an array
declare -a ssh_keys
while true; do
    if ! read -r key; then
        break  # Exit the loop on EOF (Ctrl+D)
    fi
    if [[ -n "$key" ]]; then
        ssh_keys+=("$key")
    fi
done

# If no new keys were entered, use the current keys
if [[ ${#ssh_keys[@]} -eq 0 && -n "$current_keys" ]]; then
    while IFS= read -r key; do
        if [[ -n "$key" ]]; then
            ssh_keys+=("$key")
        fi
    done <<< "$current_keys"
fi

# Write SSH keys to the temporary file
for i in "${!ssh_keys[@]}"; do
    if [[ $i -eq $((${#ssh_keys[@]}-1)) ]]; then
        # Last key - no comma
        echo "    \"${ssh_keys[$i]}\"" >> "$TMP_TF_FILE"
    else
        # Not the last key - add comma
        echo "    \"${ssh_keys[$i]}\"," >> "$TMP_TF_FILE"
    fi
done

# Close the vm_ssh_key block with proper indentation
echo "  ]" >> "$TMP_TF_FILE"
echo "}" >> "$TMP_TF_FILE"

# Loop through remaining Terraform variables, prompt user, and save to secrets.tf
for entry in "${tf_variables[@]}"; do
    var_name="${entry%%|*}"
    var_description="${entry#*|}"
    
    # Skip vm_ssh_key as we've already handled it
    if [[ "$var_name" == "vm_ssh_key" ]]; then
        continue
    fi

    # Get current value from secrets.tf if it exists, capturing only the value between quotes
    current_value=$(awk -v var="$var_name" '$0 ~ "variable \"" var "\" {" {p=1; next} p && /default = "/ {gsub(/^[^"]*"/,"",$0); gsub(/"$/, "", $0); print; p=0}' "$TF_FILE")

    # Display prompt with existing value as default
    if [[ -n "$current_value" ]]; then
        printf "%s [%s]: " "$var_description" "$current_value"
    else
        printf "%s: " "$var_description"
    fi

    # Read user input and set value
    if ! read -e input_value; then
        exit 0
    fi
    new_value="${input_value:-$current_value}"

    # Write formatted variable block to the temporary file
    cat << EOF >> "$TMP_TF_FILE"
variable "$var_name" {
  default = "$new_value"
}
EOF
done

# Display the contents of the temporary files to the user for confirmation
echo -e "\n${YELLOW}Please review the contents of the updated files:${ENDCOLOR}\n"

echo -e "${YELLOW}Contents of .env:${ENDCOLOR}"
cat "$TMP_ENV_FILE"
echo

echo -e "${YELLOW}Contents of secrets.tf:${ENDCOLOR}"
cat "$TMP_TF_FILE"
echo

# Prompt the user for confirmation
echo -n "Are these settings correct? (y/n): "
read -r confirmation
if [[ "$confirmation" != "y" && "$confirmation" != "Y" ]]; then
    echo -e "${RED}Aborting without applying changes.${ENDCOLOR}"
    exit 1
fi

# If confirmed, move the temporary files to replace the originals
mv "$TMP_ENV_FILE" "$ENV_FILE"
echo -e "${GREEN}scripts/.env file updated with provided secrets.${ENDCOLOR}"

mv "$TMP_TF_FILE" "$TF_FILE"
echo -e "${GREEN}terraform/secrets.tf file updated with provided secrets.${ENDCOLOR}"

echo -e "${GREEN}DONE${ENDCOLOR}"
