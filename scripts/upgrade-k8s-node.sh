#!/bin/bash

set -a # automatically export all variables
source /etc/k8s.env
set +a # stop automatically exporting

# TODO: Make this run automatically on remote nodes

sudo kubeadm upgrade node

sudo mkdir -m 755 /etc/apt/keyrings
sudo apt install gpg -y

# add kubernetes apt repository
sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg /etc/apt/sources.list.d/kubernetes.list
sudo bash -c "curl -fsSL \"https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_SHORT_VERSION}/deb/Release.key\" | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg"
sudo bash -c "echo \"deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_SHORT_VERSION}/deb/ /\" | tee /etc/apt/sources.list.d/kubernetes.list"

sudo apt-mark unhold kubelet kubeadm kubectl helm
sudo apt update -y
sudo apt install -y \
  kubelet="$KUBERNETES_LONG_VERSION" \
  kubeadm="$KUBERNETES_LONG_VERSION" \
  kubectl="$KUBERNETES_LONG_VERSION" \
  helm="$HELM_VERSION"
sudo apt-mark hold kubelet kubeadm kubectl helm

sudo systemctl daemon-reload
sudo systemctl restart kubelet