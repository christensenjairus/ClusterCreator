#!/usr/bin/env bash

# Workaround for broken Ubuntu 6.8.0-* kernels that randomly drop UDP packets,
# sending Cilium into CrashLoopBackOff and taking networking down for other pods
# on the node. See: https://bugs.launchpad.net/ubuntu/+source/linux/+bug/2141531
#
# Read pinned kernel version from k8s.env if available
PINNED_KERNEL_VERSION="none"
if [[ -f /etc/k8s.env ]]; then
  pinned=$(grep -oP '^PINNED_KERNEL_VERSION=\K.*' /etc/k8s.env 2>/dev/null)
  if [[ -n "$pinned" ]]; then
    PINNED_KERNEL_VERSION="$pinned"
  fi
fi

current_kernel_version=$(uname -r)

# If a kernel is pinned and we booted into a different kernel in the same
# series (e.g. 6.8.0-107 instead of pinned 6.8.0-106), skip installing
# modules for the wrong kernel — just log and exit. The GRUB default
# should already point to the pinned kernel; a reboot will fix it.
if [[ "$PINNED_KERNEL_VERSION" != "none" && "$current_kernel_version" != "$PINNED_KERNEL_VERSION" ]]; then
  pinned_series=$(echo "$PINNED_KERNEL_VERSION" | grep -oP '^\d+\.\d+\.\d+')
  current_series=$(echo "$current_kernel_version" | grep -oP '^\d+\.\d+\.\d+')
  if [[ "$pinned_series" == "$current_series" ]]; then
    echo "Booted into $current_kernel_version but pinned to $PINNED_KERNEL_VERSION (same $pinned_series series). Skipping module install to avoid rebooting into a broken kernel."
    exit 0
  fi
fi

current_kernel_package="linux-modules-extra-$current_kernel_version"

# Flag to track if a reboot is needed
reboot_needed=0

# Check if the current kernel's package is installed
if ! dpkg -l | grep -q "^ii\s\+$current_kernel_package"; then
  echo "$current_kernel_package is not installed. Installing..."

  # Update package list and install the missing package
  apt-get update -y >> /var/log/extra-kernel-modules.log 2>&1
  apt-get install -y "$current_kernel_package" >> /var/log/extra-kernel-modules.log 2>&1

  # Set reboot flag if the current kernel package was installed
  reboot_needed=1
else
  echo "$current_kernel_package is already installed."
fi

# Remove packages for non-current kernels
for kernel_version in $(dpkg --list | grep -oP "^ii\s+linux-modules-extra-\K[^\s]+" | sort -u); do
  if [[ "$kernel_version" != "$current_kernel_version" ]]; then
    echo "Removing linux-modules-extra-$kernel_version (not current kernel)"
    apt-get remove -y "linux-modules-extra-$kernel_version" >> /var/log/extra-kernel-modules.log 2>&1
  fi
done

# Reboot if the current kernel's modules were installed in this run
if (( reboot_needed )); then
  echo "Modules for the current kernel ($current_kernel_version) were just installed. Rebooting..."
  reboot
fi
