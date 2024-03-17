#!/bin/bash

# Install packages from source

set -a # automatically export all variables
source /etc/k8s.env
set +a # stop automatically exporting

export ARCH="amd64"

# Install CNI Plugins
wget "https://github.com/containernetworking/plugins/releases/download/v${CNI_PLUGINS_VERSION}/cni-plugins-linux-amd64-v${CNI_PLUGINS_VERSION}.tgz"
mkdir -p /opt/cni/bin
tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v$CNI_PLUGINS_VERSION.tgz
rm cni-plugins-linux-amd64-v$CNI_PLUGINS_VERSION.tgz

# install etcdctl
wget "https://github.com/etcd-io/etcd/releases/download/v${ETCDCTL_VERSION}/etcd-v${ETCDCTL_VERSION}-linux-amd64.tar.gz"
tar xzvf "etcd-v${ETCDCTL_VERSION}-linux-amd64.tar.gz"
install -o root -g root -m 0755 etcd-v$ETCDCTL_VERSION-linux-amd64/etcdctl /usr/local/bin/etcdctl
rm -r etcd-v$ETCDCTL_VERSION-linux-amd64*

# install cilium cli
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/v$CILIUM_CLI_VERSION/cilium-linux-${ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-$ARCH.tar.gz.sha256sum
tar xzvfC cilium-linux-$ARCH.tar.gz /usr/local/bin
rm cilium-linux-$ARCH*

# install hubble cli
curl -L --fail --remote-name-all https://github.com/cilium/hubble/releases/download/v$HUBBLE_CLI_VERSION/hubble-linux-$ARCH.tar.gz{,.sha256sum}
sha256sum --check hubble-linux-$ARCH.tar.gz.sha256sum
tar xzvfC hubble-linux-$ARCH.tar.gz /usr/local/bin
rm hubble-linux-$ARCH*

### install vtctldclient
wget https://github.com/vitessio/vitess/releases/download/v${VITESS_VERSION}/${VITESS_DOWNLOAD_FILENAME}
tar -xvzf ${VITESS_DOWNLOAD_FILENAME} --strip-components=2 -C /usr/local/bin/ ${VITESS_DOWNLOAD_FILENAME/.tar.gz/}/bin/vtctldclient
tar -xvzf ${VITESS_DOWNLOAD_FILENAME} --strip-components=3 -C /root/ ${VITESS_DOWNLOAD_FILENAME/.tar.gz/}/examples/operator/pf.sh
mv /root/pf.sh /root/vitess-port-forward.sh
rm -rf ${VITESS_DOWNLOAD_FILENAME}
