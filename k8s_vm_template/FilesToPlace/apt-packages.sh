#!/bin/bash

set -a # automatically export all variables
source /etc/k8s.env
set +a # stop automatically exporting

mkdir -m 755 /etc/apt/keyrings
apt install gpg -y

# add kubernetes apt repository
curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_SHORT_VERSION}/deb/Release.key" | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_SHORT_VERSION}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

# add helm apt repository
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list

# update apt cache
apt-get update
apt upgrade -y

# Install packages from apt
apt install -y \
bash \
curl \
grep \
git \
gcc \
open-iscsi \
lsscsi \
multipath-tools \
scsitools \
nfs-common \
sg3-utils jq \
apparmor \
apparmor-utils \
iperf \
apt-transport-https \
ca-certificates \
gnupg \
gnupg-agent \
software-properties-common \
ipvsadm \
apache2-utils \
locales-all \
python3-kubernetes \
python3-pip \
conntrack \
unzip \
ceph \
linux-generic \
intel-gpu-tools \
intel-opencl-icd \
kubelet="$KUBERNETES_LONG_VERSION" \
kubeadm="$KUBERNETES_LONG_VERSION" \
kubectl="$KUBERNETES_LONG_VERSION" \
helm="$HELM_VERSION"

# hold back kubernetes packages
apt-mark hold kubelet kubeadm kubectl helm

# install containerd, which have different package names on Debian and Ubuntu
distro=$(lsb_release -is)
if [[ "$distro" = *"Debian"* ]]; then
    echo "Installing containerd on Debian..."
    # add docker apt repository
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo apt install -y containerd.io="$CONTAINERD_VERSION"
    apt-mark hold containerd.io
elif [[ "$distro" = *"Ubuntu"* ]]; then
    echo "Installing containerd on Ubuntu..."
    sudo apt install -y containerd="$CONTAINERD_VERSION"
    apt-mark hold containerd
else
    echo "Unsupported distribution: $distro"
    exit 1
fi

# Create default containerd config
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml

# Setup cgroup drivers (will use systemd, not cgroupfs, because its native to Debian/Ubuntu)
sed -i '/SystemdCgroup = false/s/false/true/' /etc/containerd/config.toml

systemctl daemon-reload
systemctl enable containerd
systemctl enable open-iscsi
systemctl enable iscsid
systemctl enable multipathd
systemctl enable qemu-guest-agent

if [[ -n "$NVIDIA_DRIVER_VERSION" && "$NVIDIA_DRIVER_VERSION" != "none" ]]; then
  # install nvidia drivers
  wget -q "https://us.download.nvidia.com/XFree86/Linux-x86_64/${NVIDIA_DRIVER_VERSION}/NVIDIA-Linux-x86_64-${NVIDIA_DRIVER_VERSION}.run"
  chmod +x "./NVIDIA-Linux-x86_64-${NVIDIA_DRIVER_VERSION}.run"
  ./"NVIDIA-Linux-x86_64-${NVIDIA_DRIVER_VERSION}.run" --silent
  rm -f "./NVIDIA-Linux-x86_64-${NVIDIA_DRIVER_VERSION}.run"

  # add nvidia-container-toolkit apt repository
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
    && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
      sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
      sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

  apt-get update

  # install nvidia toolkit/runtime
  apt install -y \
    nvidia-container-toolkit \
    nvidia-container-runtime
fi
