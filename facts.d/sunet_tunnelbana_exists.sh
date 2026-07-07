#!/bin/sh

if systemctl list-unit-files sunet-tunnelbana.service | grep sunet-tunnelbana -q; then
    echo "sunet_tunnelbana_exists=yes"
else
    echo "sunet_tunnelbana_exists=no"
fi
