#!/bin/bash

set -a # automatically export all variables
source .env
set +a # stop automatically exporting

scp ./.env ./proxmox_scripts/create_template_helper.sh ~/.ssh/${NON_PASSWORD_PROTECTED_SSH_KEY}.pub $PROXMOX_USERNAME@$PROXMOX_HOST:
ssh $PROXMOX_USERNAME@$PROXMOX_HOST "chmod +x ./create_template_helper.sh && ./create_template_helper.sh"
ssh $PROXMOX_USERNAME@$PROXMOX_HOST "rm .env create_template_helper.sh ${NON_PASSWORD_PROTECTED_SSH_KEY}.pub"