#!/bin/sh

if systemctl list-unit-files --state=enabled | grep fail2ban -q; then
    echo "fail2ban_is_enabled=yes"
else
    echo "fail2ban_is_enabled=no"
fi

