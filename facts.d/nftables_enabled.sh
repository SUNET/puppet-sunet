#!/bin/sh

if [ -f /etc/sunet-nftables-opt-in ]; then
    echo "sunet_nftables_opt_in=yes"
else
    echo "sunet_nftables_opt_in=no"
fi
