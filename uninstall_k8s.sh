#!/bin/bash

source .env

pushd ./ansible

cleanup_function() {
  rm \
    ansible/tmp/wrkr_join_command.sh \
    ansible/tmp/cp_join_command.sh \
    >&/dev/null
  popd
  echo "Cleanup complete."
}

# run ansible playbooks
ansible-playbook -i tmp/ansible-hosts.txt -u $VM_USERNAME ansible-reset-cluster.yaml

# cleanup join commands
cleanup_function