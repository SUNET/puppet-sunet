#!/bin/sh
#
# This finds (hopefully) the public interface based on default route

INT=$(ip route | grep default | sed -e 's/.*dev //' | awk '{print $1}')

# Try to handle IPv6 only hosts too
if [ "x${INT}" = "x" ]; then
    INT=$(ip -6 route list default | head -1 | sed -e 's/.* dev //' | awk '{print $1}')
fi

if [ "x${INT}" != "x" ]; then
    echo "interface_default=${INT}"
fi

