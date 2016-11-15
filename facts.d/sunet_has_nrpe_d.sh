#!/bin/sh

if [ -d /etc/nagios/nrpe.d ]; then
    echo "sunet_has_nrpe_d=true"
else
    echo "sunet_has_nrpe_d=false"
fi

