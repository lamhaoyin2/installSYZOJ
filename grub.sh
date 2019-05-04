#!/bin/bash

sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT="\ cgroup_enable=memory\ swapaccount=1/' /etc/default/grub
update-grub && reboot
