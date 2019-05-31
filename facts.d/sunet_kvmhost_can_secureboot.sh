#!/bin/sh
#
# Fact to check if a recent enough `ovmf' package is installed on a kvmhost.
# The ovmf package needed was not available in Ubuntu 18.04.
#

if [ -f /usr/share/OVMF/OVMF_CODE.secboot.fd -a -f /usr/share/OVMF/OVMF_VARS.ms.fd ]; then
    echo "sunet_kvmhost_can_secureboot=true"
else
    echo "sunet_kvmhost_can_secureboot=false"
fi
