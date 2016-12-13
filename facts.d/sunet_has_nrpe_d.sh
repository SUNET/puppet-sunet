#!/bin/sh

if [ -d /etc/nagios/nrpe.d ]; then
    echo "sunet_has_nrpe_d=yes"
else
    echo "sunet_has_nrpe_d=no"
fi

