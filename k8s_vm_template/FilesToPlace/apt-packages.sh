#!/bin/bash

set -a # automatically export all variables
source /etc/k8s.env
set +a # stop automatically exporting

# Set non-interactive mode for apt commands
export DEBIAN_FRONTEND=noninteractive

# install all locales, gpg, bc (essentials for scripts to work)
apt install -y \
  locales-all \
  gpg \
  bc

# generate locales
echo -e "export LANGUAGE=en_US\nexport LANG=en_US.UTF-8" >> /etc/environment
source /etc/environment
locale-gen en_US.UTF-8
dpkg-reconfigure --frontend=noninteractive locales

# Preconfigure keyboard settings for both Ubuntu and Debian
echo "keyboard-configuration keyboard-configuration/layout select 'English (US)'" | debconf-set-selections
echo "keyboard-configuration keyboard-configuration/layoutcode string 'us'" | debconf-set-selections
echo "keyboard-configuration keyboard-configuration/model select 'Generic 105-key PC (intl.)'" | debconf-set-selections
echo "keyboard-configuration keyboard-configuration/variant select 'English (US)'" | debconf-set-selections

mkdir -m 755 /etc/apt/keyrings

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
gnupg-agent \
software-properties-common \
ipvsadm \
apache2-utils \
python3-kubernetes \
python3-pip \
conntrack \
unzip \
ceph \
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

    echo "Installing linux-generic to help with recognizing intel gpus..."
    apt install -y
      linux-generic
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
  if [[ "$distro" = *"Debian"* ]]; then

    # add contrib, non-free, and non-free-firmware components to sources.list
    sed -i '/^Components:/ s/main/main contrib non-free non-free-firmware/' /etc/apt/sources.list.d/debian.sources

    apt-get update

    # install nvidia kernel modules
    apt install -y \
      "linux-headers-$(uname -r)"

    # install nvidia driver
    apt install -y \
      nvidia-driver \
      firmware-misc-nonfree

  elif [[ "$distro" = *"Ubuntu"* ]]; then

    # install nvidia kernel modules
    apt install -y \
      "linux-modules-nvidia-${NVIDIA_DRIVER_VERSION}-server-generic" \
      "linux-headers-generic" \
      "nvidia-dkms-${NVIDIA_DRIVER_VERSION}-server"

    # install nvidia driver
    apt install -y \
      "nvidia-driver-${NVIDIA_DRIVER_VERSION}-server"

  else
    echo "Unsupported distribution: $distro"
    exit 1
  fi

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

# extraneous package cleanup
apt autoremove -y
