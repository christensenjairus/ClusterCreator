#!/bin/bash

# Load the environment variables from the .env file
set -a # automatically export all variables
source .env
set +a # stop automatically exporting

cd $PROXMOX_ISO_PATH

# original img
rm -f ./$IMAGE_NAME*

# Source the image
wget $IMAGE_LINK

# add packages to image
virt-customize -a ./$IMAGE_NAME --install qemu-guest-agent,bash,curl,grep,nfs-common,open-iscsi,lsscsi,sg3-utils,multipath-tools,scsitools,jq,apparmor,apparmor-utils,iperf,apt-transport-https,ca-certificates,gpg,gnupg-agent,software-properties-common,ipvsadm,python3-pip

# enable services
virt-customize -a ./$IMAGE_NAME --run-command 'sudo systemctl enable open-iscsi && sudo systemctl enable iscsid && sudo systemctl enable multipathd && sudo systemctl enable qemu-guest-agent'

# edit multipath.conf
virt-customize -a ./$IMAGE_NAME --run-command 'echo "defaults {\n    user_friendly_names yes\n    find_multipaths yes\n}\nblacklist {\n    devnode \"^sd[a-z0-9]+\"\n}" > /etc/multipath.conf'

# set timezone
virt-customize -a ./$IMAGE_NAME --timezone $TIMEZONE

# Delete old template if exists
qm destroy $TEMPLATE_VM_ID --purge 1 --skiplock 1 --destroy-unreferenced-disks 1 &>/dev/null

# Create the instance
qm create $TEMPLATE_VM_ID \
  --name ubuntu-jammy-cloudinit \
  --cores 1 \
  --sockets 1 \
  --memory 1024 \
  --net0 virtio,bridge=vmbr0,tag=1 \
  --agent "enabled=1,freeze-fs-on-backup=1,fstrim_cloned_disks=1" \
  --onboot 1 \
  --autostart 1 \
  --balloon 0 \
  --cpu cputype=host \
  --numa 1

qm importdisk $TEMPLATE_VM_ID ./$IMAGE_NAME nvmes

qm set $TEMPLATE_VM_ID \
  --scsihw virtio-scsi-pci \
  --virtio0 nvmes:vm-9000-disk-0 \
  --ide2 nvmes:cloudinit \
  --boot c \
  --bootdisk virtio0 \
  --serial0 socket \
  --vga serial0 \
  --ciuser $VM_USERNAME \
  --cipassword "$VM_PASSWORD" \
  --ipconfig0 gw="$TEMPLATE_VM_GATEWAY",ip="$TEMPLATE_VM_IP" \
  --nameserver "$TWO_DNS_SERVERS $TEMPLATE_VM_GATEWAY" \
  --searchdomain "$TEMPLATE_VM_SEARCH_DOMAIN" \
  --sshkeys "$HOME/${NON_PASSWORD_PROTECTED_SSH_KEY}.pub" \
  --agent 1 \
  --hotplug disk,network,usb

#qm resize $TEMPLATE_VM_ID virtio0 8G # leave this for terraform

qm template $TEMPLATE_VM_ID

# original img
rm -f ./IMAGE_NAME

echo "Template created successfully."