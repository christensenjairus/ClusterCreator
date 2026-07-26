#!/usr/bin/env bash

usage() {
  echo "Usage: ccr configure-secrets"
  echo ""
  echo "Opens the encrypted secrets file (secrets.sops.yaml) in your editor via SOPS."
  echo "Values are decrypted for editing and automatically re-encrypted on save."
  echo ""
  echo "The age private key is loaded from 1Password (\$SOPS_AGE_OP_REF) if the 'op'"
  echo "CLI is available, otherwise from \$SOPS_AGE_KEY_FILE (~/.config/sops/age/keys.txt)."
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown parameter passed: $1"; usage; exit 1 ;;
    esac
    shift
done

set -e

SECRETS_FILE="$REPO_PATH/secrets.sops.yaml"
EXAMPLE_FILE="$REPO_PATH/secrets.sops.example.yaml"

# Load the age key: prefer 1Password, fall back to the standard key file.
if [[ -z "$SOPS_AGE_KEY" && -z "$SOPS_AGE_KEY_FILE" ]]; then
    if command -v op &>/dev/null && op read "$SOPS_AGE_OP_REF" &>/dev/null; then
        SOPS_AGE_KEY="$(op read "$SOPS_AGE_OP_REF")"
        export SOPS_AGE_KEY
    else
        export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
        echo -e "${YELLOW}Note: 1Password unavailable; using key file $SOPS_AGE_KEY_FILE${ENDCOLOR}"
    fi
fi

# Run from the repo root so SOPS can find the .sops.yaml creation rules.
cd "$REPO_PATH"

# Bootstrap the encrypted file from the example template on first use.
if [[ ! -f "$SECRETS_FILE" ]]; then
    echo -e "${YELLOW}secrets.sops.yaml not found — creating an encrypted copy from the example template.${ENDCOLOR}"
    tmp="$(mktemp)"
    trap 'rm -f "$tmp"' EXIT
    cp "$EXAMPLE_FILE" "$tmp"
    sops --config "$REPO_PATH/.sops.yaml" -e "$tmp" > "$SECRETS_FILE"
fi

echo -e "${GREEN}Opening secrets.sops.yaml (decrypt -> edit -> re-encrypt on save)...${ENDCOLOR}"
echo -e "${BLUE}Fill in every REPLACE_ME value, then save & quit your editor.${ENDCOLOR}"
exec sops "$SECRETS_FILE"
