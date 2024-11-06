#!/bin/bash

# Record the start time
start_time_total=$(date +%s)

GREEN='\033[32m'
ENDCOLOR='\033[0m'

echo -e "${GREEN}Ensuring libguestfs-tools and jq are installed...${ENDCOLOR}"
apt install jq libguestfs-tools -y

echo ""
echo -e "${GREEN}Loading the environment variables from the .env files...${ENDCOLOR}"
set -a # automatically export all variables
source .env
source k8s.env
set +a # stop automatically exporting

set -e

echo -e "${GREEN}Removing old image if it exists...${ENDCOLOR}"
rm -f "${PROXMOX_ISO_PATH:?PROXMOX_ISO_PATH is not set}/${IMAGE_NAME:?IMAGE_NAME is not set}"* 2>/dev/null || true

echo -e "${GREEN}Downloading the image to get new updates...${ENDCOLOR}"
wget -qO "$PROXMOX_ISO_PATH"/"$IMAGE_NAME" "$IMAGE_LINK"
echo ""

echo -e "${GREEN}Update, add packages, enable services, edit multipath config, set timezone, set firstboot scripts...${ENDCOLOR}"
virt-customize -a "$PROXMOX_ISO_PATH"/"$IMAGE_NAME" \
     --mkdir /etc/systemd/system/containerd.service.d/ \
     --copy-in ./FilesToPlace/override.conf:/etc/systemd/system/containerd.service.d/ \
     --copy-in ./FilesToPlace/multipath.conf:/etc/ \
     --copy-in ./FilesToPlace/k8s_mods.conf:/etc/modules-load.d/ \
     --copy-in ./FilesToPlace/k8s_sysctl.conf:/etc/sysctl.d/ \
     --copy-in ./FilesToPlace/99-inotify-limits.conf:/etc/sysctl.d/ \
     --copy-in ./FilesToPlace/80-hotplug-cpu.rules:/lib/udev/rules.d/ \
     --copy-in ./FilesToPlace/apt-packages.sh:/root/ \
     --copy-in ./FilesToPlace/source-packages.sh:/root/ \
     --copy-in ./FilesToPlace/watch-disk-space.sh:/root/ \
     --copy-in ./FilesToPlace/extra-kernel-modules.sh:/root/ \
     --copy-in k8s.env:/etc/ \
     --install qemu-guest-agent,cloud-init \
     --timezone "$TIMEZONE" \
     --firstboot ./FilesToRun/install_packages.sh
     # firstboot script creates /tmp/.firstboot when finished

echo -e "${GREEN}Deleting the old template vm if it exists...${ENDCOLOR}"
qm stop "$TEMPLATE_VM_ID" --skiplock 1 || true
qm destroy "$TEMPLATE_VM_ID" --purge 1 --skiplock 1 --destroy-unreferenced-disks 1 || true

echo -e "${GREEN}Creating the VM...${ENDCOLOR}"
qm create "$TEMPLATE_VM_ID" \
  --name "$TEMPLATE_VM_NAME" \
  --machine "type=q35" \
  --cores "$TEMPLATE_VM_CPU" \
  --sockets 1 \
  --memory "$TEMPLATE_VM_MEM" \
  --net0 virtio,bridge=vmbr0 \
  --agent "enabled=1,freeze-fs-on-backup=1,fstrim_cloned_disks=1" \
  --onboot 1 \
  --balloon 0 \
  --autostart 1 \
  --cpu cputype=x86-64-v2-AES \
  --numa 1

echo -e "${GREEN}Importing the disk...${ENDCOLOR}"
qm importdisk "$TEMPLATE_VM_ID" "$PROXMOX_ISO_PATH"/"$IMAGE_NAME" "$PROXMOX_DATASTORE"

echo -e "${GREEN}Setting the VM options...${ENDCOLOR}"
qm set "$TEMPLATE_VM_ID" \
  --scsihw virtio-scsi-pci \
  --virtio0 "${PROXMOX_DATASTORE}:vm-${TEMPLATE_VM_ID}-disk-0,iothread=1" \
  --ide2 "${PROXMOX_DATASTORE}:cloudinit" \
  --boot c \
  --bootdisk virtio0 \
  --serial0 socket \
  --vga serial0 \
  --ciuser "$VM_USERNAME" \
  --cipassword "$VM_PASSWORD" \
  --ipconfig0 gw="$TEMPLATE_VM_GATEWAY",ip="$TEMPLATE_VM_IP" \
  --nameserver "$TWO_DNS_SERVERS $TEMPLATE_VM_GATEWAY" \
  --searchdomain "$TEMPLATE_VM_SEARCH_DOMAIN" \
  --sshkeys "${NON_PASSWORD_PROTECTED_SSH_KEY}.pub" \
  --agent 1 \
  --hotplug cpu,disk,network,usb \
  --tags "$EXTRA_TEMPLATE_TAGS ${KUBERNETES_MEDIUM_VERSION}"

echo -e "${GREEN}Expanding disk to $TEMPLATE_DISK_SIZE...${ENDCOLOR}"
qm resize "$TEMPLATE_VM_ID" virtio0 "$TEMPLATE_DISK_SIZE"

echo -e "${GREEN}Starting the VM, allowing firstboot script to install packages...${ENDCOLOR}"
qm start "$TEMPLATE_VM_ID"

start_time_packages=$(date +%s)

echo -e "${GREEN}Sleeping 60s to allow VM and the QEMU Guest Agent to start...${ENDCOLOR}"
sleep 60s

echo -e -n "${GREEN}Waiting for all packages to be installed${ENDCOLOR}"
while true; do
  output=$(qm guest exec "$TEMPLATE_VM_ID" cat /tmp/.firstboot 2>/dev/null)
  success=$?
  if [[ $success -eq 0 ]]; then
    exit_code=$(echo "$output" | jq '.exitcode')
    if [[ $? -eq 0 && $exit_code -eq 0 ]]; then
      echo -e "\n${GREEN}Firstboot complete. Proceeding with cloud-init reset and shutdown...${ENDCOLOR}"
      break
    fi
  fi
  echo -n "."
  sleep 2
done

end_time_packages=$(date +%s)
elapsed_time_packages=$(( end_time_packages - start_time_packages ))
echo -e "${GREEN}Elapsed time installing packages: $((elapsed_time_packages / 60)) minutes and $((elapsed_time_packages % 60)) seconds.${ENDCOLOR}"

echo -e "${GREEN}Print out disk space stats...${ENDCOLOR}"
qm guest exec "$TEMPLATE_VM_ID" -- /bin/sh -c "cat /var/log/watch-disk-space.txt" | jq -r '.["out-data"]'

echo -e "${GREEN}Clean out cloudconfig configuration...${ENDCOLOR}"
qm guest exec "$TEMPLATE_VM_ID" -- /bin/sh -c  "rm -f /etc/cloud/clean.d/README && cloud-init clean --logs" >/dev/null

echo -e "${GREEN}Shutting down the VM gracefully...${ENDCOLOR}"
qm shutdown "$TEMPLATE_VM_ID"

echo -e "${GREEN}Converting the shut-down VM into a template...${ENDCOLOR}"
qm template "$TEMPLATE_VM_ID"

echo -e "${GREEN}Deleting the downloaded image...${ENDCOLOR}"
rm -f "${PROXMOX_ISO_PATH:?PROXMOX_ISO_PATH is not set}/${IMAGE_NAME:?IMAGE_NAME is not set}"*

echo -e "${GREEN}Template created successfully${ENDCOLOR}"

end_time_total=$(date +%s)
elapsed_time_total=$(( end_time_total - start_time_total ))
echo -e "${GREEN}Total elapsed time: $((elapsed_time_total / 60)) minutes and $((elapsed_time_total % 60)) seconds.${ENDCOLOR}"
