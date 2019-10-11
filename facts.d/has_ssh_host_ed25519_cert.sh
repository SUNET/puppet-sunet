#!/bin/sh

if [ -f /etc/ssh/ssh_host_ed25519_key-cert ]; then
   echo "has_ssh_host_ed25519_cert=yes"
else
   echo "has_ssh_host_ed25519_cert=no"
fi
