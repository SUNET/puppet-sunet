#!/bin/sh
#
# FIXME: Might have to handle hosts with more than one IP-address on the "outside"
# 	 interface, this script *should* pick one and still work, but ...

INT=$(ip route list default | grep " dev " | head -1 | sed -e 's/.* dev //' | awk '{print $1}')

if [ "x${INT}" != "x" ]; then
    # This command works on Ubuntu 16.10 and later (?)
    ipaddr4=$(ip -4 addr show dev "${INT}" up scope global | grep inet | head -1 | awk '{print $2}' | cut -d / -f 1)
    if [ "x$ipaddr4" = "x" ]; then
	# This command works on Ubuntu 16.04 and earlier (?)
	ipaddr4=$(ifconfig $INT | grep "inet addr" | head -1 | cut -d ':' -f 2 | cut -d ' ' -f 1)
    fi

    if [ "x$ipaddr4" != "x" ]; then
	echo "ipaddress_default=$ipaddr4"
    fi
fi

# Make sure to not assume the default interface for v4 traffic is the same as for v6
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
INT=$(ip -6 route list default | grep " dev " | head -1 | sed -e 's/.* dev //' | awk '{print $1}')

if [ "x${INT}" != "x" ]; then
    ipaddr6=$(ip -6 addr show dev "${INT}" up scope global | grep inet6 | head -1 | awk '{print $2}' | cut -d / -f 1)
    if [ "x$ipaddr6" != "x" ]; then
	echo "ipaddress6_default=$ipaddr6"
    fi
fi
