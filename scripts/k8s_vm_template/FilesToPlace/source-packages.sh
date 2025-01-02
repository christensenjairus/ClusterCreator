#!/bin/bash

# Install packages from source
# MIRRORS ansible/reinstall-source-packages.yaml

set -a # automatically export all variables
source /etc/k8s.env
source /etc/.env
set +a # stop automatically exporting

export ARCH="amd64"

# Install CNI Plugins
wget -q "https://github.com/containernetworking/plugins/releases/download/v${CNI_PLUGINS_VERSION}/cni-plugins-linux-amd64-v${CNI_PLUGINS_VERSION}.tgz"
mkdir -p /opt/cni/bin
tar Cxzvf /opt/cni/bin "cni-plugins-linux-amd64-v$CNI_PLUGINS_VERSION.tgz"
rm "cni-plugins-linux-amd64-v$CNI_PLUGINS_VERSION.tgz"
chown -R root:root /opt/cni/bin # https://github.com/cilium/cilium/issues/23838

### install yq
wget -q https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq
chmod +x /usr/local/bin/yq

### install yj
wget -q https://github.com/sclevine/yj/releases/download/v5.1.0/yj-linux-amd64 -O /usr/local/bin/yj
chmod +x /usr/local/bin/yj
