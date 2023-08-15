#!/bin/sh

if systemctl list-unit-files sunet-naemon_monitor.service | grep naemon_monitor -q; then
    echo "sunet_naemon_monitor=yes"
else
    echo "sunet_naemon_monitor=no"
fi

