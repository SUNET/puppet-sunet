#!/bin/sh

if [ -d /etc/nagios/nrpe.d ]; then
    echo -n "sunet_has_nrpe_d=true"
else
    echo -n "sunet_has_nrpe_d=false"
fi

