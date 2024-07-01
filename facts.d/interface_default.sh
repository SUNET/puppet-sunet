#!/bin/sh
#
# This finds (hopefully) the public interface based on default route

INT=$(ip route | grep default | sed -e 's/.*dev //' | awk '{print $1}')

# Try to handle IPv6 only hosts too
#
# The syntax of the output of the "ip route list" here is either
#
#   default proto static metric 1024 pref medium
#        nexthop via 2001:6b0:x:y::1 dev eth0 weight 1
#        nexthop via fe80::abcd::... dev eth0 weight 1
#
# or
#
#   default via 2001:6b0:x:y::1 dev eth0 proto static metric 1024 pref medium
#
if [ "x${INT}" = "x" ]; then
    INT=$(ip -6 route list default | grep " dev " | head -1 | sed -e 's/.* dev //' | awk '{print $1}')
fi

if [ "x${INT}" != "x" ]; then
    echo "interface_default=${INT}"
fi
