#!/bin/bash

for container in $(ctr -n k8s.io containers list -q); do
  ctr -n k8s.io tasks kill --all --signal SIGKILL "$container" || true >/dev/null 2>&1 || true
  sleep 1
  ctr -n k8s.io tasks delete "$container" >/dev/null 2>&1 || true
  ctr -n k8s.io containers delete "$container"
done
