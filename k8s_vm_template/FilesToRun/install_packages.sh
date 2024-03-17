#!/bin/bash

echo "LANG=en_US.UTF-8
LANGUAGE=en_US" > /etc/default/locale
localectl set-locale LANG=en_US.UTF-8
touch /var/lib/cloud/instance/locale-check.skip

chmod +x /root/*.sh

# These can run simultaneously because they don't depend on each other

/root/apt-packages.sh >> /var/log/template-firstboot-1-apt-packages.log 2>&1 &
/root/source-packages.sh >> /var/log/template-firstboot-2-source-packages.log 2>&1 &

wait

# cleanup
rm -f /root/apt-packages.sh /root/source-packages.sh

# signal to create_template_helper.sh that firstboot scripts are done
touch /tmp/.firstboot
