#!/bin/bash

echo "LANG=en_US.UTF-8
LANGUAGE=en_US" > /etc/default/locale
localectl set-locale LANG=en_US.UTF-8
touch /var/lib/cloud/instance/locale-check.skip

chmod +x /root/*.sh

# These can run simultaneously because they don't depend on each other

/root/apt-packages.sh >> /var/log/template-firstboot-1-apt-packages.log 2>&1 &
pid1=$!
/root/source-packages.sh >> /var/log/template-firstboot-2-source-packages.log 2>&1 &
pid2=$!
/root/watch-disk-space.sh >/dev/null 2>&1 &
pid3=$!

# wait for the first two to complete
wait $pid1 $pid2

# kill the third one, which would otherwise run indefinitely
kill $pid3

# cleanup
rm -f /root/apt-packages.sh /root/source-packages.sh /root/watch-disk-space.sh

# signal to create_template_helper.sh that firstboot scripts are done
touch /tmp/.firstboot
