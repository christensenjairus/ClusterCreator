#!/bin/bash

# encryption-manifest-edit.sh
# Simple script to add encryption flags to kube-apiserver manifest and restart it

set -euo pipefail

# Configuration
KUBE_API_MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"
ETCD_ENC_FILE="/etc/kubernetes/enc/enc.yaml"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This script must be run as root"
    exit 1
fi

# Check if kube-apiserver manifest exists
if [[ ! -f "$KUBE_API_MANIFEST" ]]; then
    echo "WARNING: kube-apiserver manifest not found at $KUBE_API_MANIFEST, nothing to do"
    exit 0
fi

# Check if etcd encryption file exists
if [[ ! -f "$ETCD_ENC_FILE" ]]; then
    echo "WARNING: etcd encryption file not found at $ETCD_ENC_FILE, nothing to do"
    exit 0
fi

# Check if encryption is already configured
echo "Checking if encryption is already configured..."
if grep -q 'encryption-provider-config=/etc/kubernetes/enc/enc.yaml' "$KUBE_API_MANIFEST" 2>/dev/null; then
    echo "Encryption already configured in kube-apiserver manifest, nothing to do"
    exit 0
fi
echo "Encryption not found, proceeding with setup..."

echo "Adding encryption configuration to kube-apiserver manifest"

# Check if yq is available
if ! command -v yq &> /dev/null; then
    echo "ERROR: yq is required but not installed. Please install yq first."
    exit 1
fi

# Add encryption configuration using yq
if ! yq eval '
  .spec.containers[0].command |=
    (select(.) | map(select(. != "--encryption-provider-config=/etc/kubernetes/enc/enc.yaml")) + ["--encryption-provider-config=/etc/kubernetes/enc/enc.yaml"]) |
  .spec.containers[0].volumeMounts |=
    (select(.) | map(select(.name != "enc")) + [{"name": "enc", "mountPath": "/etc/kubernetes/enc", "readOnly": true}]) |
  .spec.volumes |=
    (select(.) | map(select(.name != "enc")) + [{"name": "enc", "hostPath": {"path": "/etc/kubernetes/enc", "type": "DirectoryOrCreate"}}])
' -i "$KUBE_API_MANIFEST"; then
    echo "ERROR: Failed to modify kube-apiserver manifest"
    exit 1
fi

echo "Removing apiserver container to force restart"

# Find and remove apiserver container
container_id=$(crictl ps -a | grep apiserver | awk '{print $1}' 2>/dev/null || true)

if [[ -n "$container_id" ]]; then
    echo "Found apiserver container: $container_id"
    if ! crictl rm -f "$container_id" 2>/dev/null; then
        echo "WARNING: Failed to remove apiserver container (this may be normal)"
    fi
else
    echo "No apiserver container found"
fi

echo "Restarting kubelet service"
if ! systemctl restart kubelet; then
    echo "ERROR: Failed to restart kubelet service"
    exit 1
fi

echo "etcd encryption setup completed"
