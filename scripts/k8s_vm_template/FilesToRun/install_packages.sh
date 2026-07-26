#!/usr/bin/env bash

set -a # automatically export all variables
source /etc/k8s.env
set +a # stop automatically exporting

chmod +x /root/*.sh

# These can run simultaneously because they don't depend on each other

/root/apt-packages.sh >> /var/log/template-firstboot-1-apt-packages.log 2>&1 &
pid1=$!
/root/source-packages.sh >> /var/log/template-firstboot-2-source-packages.log 2>&1 &
pid2=$!
/root/watch-disk-space.sh >/dev/null 2>&1 &
pid3=$!

# wait for the first two to complete, capturing each exit status
wait "$pid1"; status_apt=$?
wait "$pid2"; status_source=$?

# kill the third one, which would otherwise run indefinitely
kill "$pid3" 2>/dev/null || true

# cleanup
rm -f /root/apt-packages.sh /root/source-packages.sh /root/watch-disk-space.sh

# Signal to create_template_helper.sh that firstboot scripts are done, carrying
# the real result: "0" means success, anything else means an installer failed.
# (Previously this always touched an empty file, so the host could never tell a
# failed package install from a successful one.)
if [[ $status_apt -eq 0 && $status_source -eq 0 ]]; then
  echo 0 > /tmp/.firstboot
else
  echo "FAILED apt=$status_apt source=$status_source" > /tmp/.firstboot
fi
