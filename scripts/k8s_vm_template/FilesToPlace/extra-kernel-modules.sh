#!/bin/bash

# Define the package for the current kernel
current_kernel_version=$(uname -r)
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
