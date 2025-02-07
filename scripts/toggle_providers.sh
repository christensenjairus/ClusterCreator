#!/bin/bash

usage() {
  echo "Usage: ccr toggle-providers"
  echo ""
  echo "Comments out providers and their secrets for those users that don't wish to use them, then guides the user through setting their secrets and initializing tofu."
  echo ""
  echo "Providers that can be toggled:"
  echo "  * Unifi - toggling off will stop trying to make networks/vlans with Unifi."
  echo "  * Minio - toggling off will store all terraform state locally instead of in Minio's S3-compatible storage"
}

# Prompt the user
echo -e "${YELLOW}Are you using MinIO to store the Terraform state? (y/n)${ENDCOLOR}"
read -r use_minio
echo -e "${YELLOW}Are you using Unifi as part of your setup? (y/n)$ENDCOLOR"
read -r use_unifi

# General function to toggle a block in a Terraform file using awk for balanced braces
toggle_tf_block() {
    local start_pattern="$1"
    local condition="$2"
    local file="$3"

    if [[ "$condition" == "y" ]]; then
        # Uncomment block: remove leading '# ' from each line within the block
        awk -v pat="$start_pattern" '
            BEGIN { inside = 0; brace_count = 0 }
            $0 ~ "^# *" pat { inside = 1 }
            inside {
                sub(/^# /, "", $0)
                if ($0 ~ /{/) brace_count++
                if ($0 ~ /}/) brace_count--
                if (brace_count == 0) inside = 0
            }
            { print }
        ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    else
        # Comment block: add '# ' at the start of each line within the block
        awk -v pat="$start_pattern" '
            BEGIN { inside = 0; brace_count = 0 }
            $0 ~ pat { inside = 1 }
            inside {
                if ($0 !~ /^#/) $0 = "# " $0
                if ($0 ~ /{/) brace_count++
                if ($0 ~ /}/) brace_count--
                if (brace_count == 0) inside = 0
            }
            { print }
        ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    fi
}

# Function to toggle specific lines in configure_secrets.sh
toggle_secrets_lines() {
    local line_pattern="$1"
    local condition="$2"
    local file="$3"

    if [[ "$condition" == "y" ]]; then
        # Uncomment lines: remove leading '#' from matching lines while maintaining indentation
        awk -v pat="$line_pattern" '
            $0 ~ pat && /^# / { sub(/^# /, "", $0) }
            { print }
        ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    else
        # Comment lines: add '# ' at the start of matching lines while preserving indentation
        awk -v pat="$line_pattern" '
            $0 ~ pat && $0 !~ /^# / { $0 = "# " $0 }
            { print }
        ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    fi
}

# Define the file path variables
providers_file="$REPO_PATH/terraform/providers.tf"
secrets_file="$REPO_PATH/scripts/configure_secrets.sh"
variables_file="$REPO_PATH/terraform/variables.tf"
unifi_file="$REPO_PATH/terraform/unifi.tf"

# Toggle specific blocks in providers.tf based on user input
toggle_tf_block "aws =" "$use_minio" "$providers_file"
toggle_tf_block "unifi =" "$use_unifi" "$providers_file"
toggle_tf_block 'backend "s3"' "$use_minio" "$providers_file"
toggle_tf_block 'provider "aws"' "$use_minio" "$providers_file"
toggle_tf_block 'provider "unifi"' "$use_unifi" "$providers_file"
toggle_tf_block 'resource "unifi_network"' "$use_unifi" "$unifi_file"

# Toggle minio-related lines in configure_secrets.sh
toggle_secrets_lines "minio_access_key" "$use_minio" "$secrets_file"
toggle_secrets_lines "minio_secret_key" "$use_minio" "$secrets_file"

# Toggle minio-related lines in variables.tf
toggle_secrets_lines "minio_bucket" "$use_minio" "$variables_file"
toggle_secrets_lines "minio_region" "$use_minio" "$variables_file"
toggle_secrets_lines "minio_endpoint" "$use_minio" "$variables_file"

# Toggle unifi-related lines in configure_secrets.sh
toggle_secrets_lines "unifi_username" "$use_unifi" "$secrets_file"
toggle_secrets_lines "unifi_password" "$use_unifi" "$secrets_file"

# Toggle unifi-related lines in variables.tf
toggle_secrets_lines "unifi_api_url" "$use_unifi" "$variables_file"

chmod +x "$secrets_file"

echo -e "${GREEN}Configuration has been updated based on your selections.${ENDCOLOR}"

echo ""
echo -e "${GREEN}Setting variables (new providers may need new variables)${ENDCOLOR}"
"${REPO_PATH}/clustercreator.sh" configure-variables

echo ""
echo -e "${GREEN}Setting secrets (new providers may need new secrets)${ENDCOLOR}"
"${REPO_PATH}/clustercreator.sh" configure-secrets

echo ""
echo -e "${GREEN}Running tofu init to initialize new providers${ENDCOLOR}"
"${REPO_PATH}/clustercreator.sh" tofu init -upgrade -reconfigure

echo -e "${GREEN}DONE${ENDCOLOR}"
