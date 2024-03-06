#!/bin/bash

source .env

ansible-galaxy collection install kubernetes.core

set -e
trap 'echo "An error occurred. Cleaning up..."; cleanup_function' ERR

pushd ./ansible

cleanup_function() {
  rm \
    ansible/tmp/wrkr_join_command.sh \
    ansible/tmp/cp_join_command.sh \
    >&/dev/null
  popd
  echo "Cleanup complete."
}

ansible-playbook -u $VM_USERNAME ansible-generate-ansible-hosts-txt.yaml

# run ansible playbooks
ansible-playbook -i tmp/ansible-hosts.txt -u $VM_USERNAME ansible-master-playbook.yaml \
  -e "cloudflare_global_api_key=${GLOBAL_CLOUDFLARE_API_KEY}" \
  -e "ssh_key_file=$HOME/.ssh/${NON_PASSWORD_PROTECTED_SSH_KEY}" \
  -e "ssh_hosts_file=$HOME/.ssh/known_hosts"

echo "CLUSTER COMPLETE"

# cleanup join commands
cleanup_function