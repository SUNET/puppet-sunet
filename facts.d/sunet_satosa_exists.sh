#!/bin/sh

if systemctl list-unit-files sunet-satosa.service | grep sunet-satosa -q; then
    echo "sunet_satosa_exists=yes"
else
    echo "sunet_satosa_exists=no"
fi

