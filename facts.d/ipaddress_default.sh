#!/bin/sh
#
# FIXME: Might have to handle hosts with more than one IP-address on the "outside"
# 	 interface, this script *should* pick one and still work, but ...

INT=$(ip route list default | head -1 | sed -e 's/.* dev //' | awk '{print $1}')

if [ "x${INT}" != "x" ]; then
    # This command works on Ubuntu 16.04 and earlier (?)
    ipaddr4=$(ifconfig $INT | grep "inet addr" | head -1 | cut -d ':' -f 2 | cut -d ' ' -f 1)
    if [ "x$ipaddr4" = "x" ]; then
	# Try again with command that works on Ubuntu 16.10 and later (?)
	ipaddr4=$(ip -4 addr show dev "${INT}" up scope global | grep inet | head -1 | awk '{print $2}' | cut -d / -f 1)
    fi

    if [ "x$ipaddr4" != "x" ]; then
	echo "ipaddress_default=$ipaddr4"
    fi
fi

# Make sure to not assume the default interface for v4 traffic is the same as for v6
INT=$(ip -6 route list default | head -1 | sed -e 's/.* dev //' | awk '{print $1}')

if [ "x${INT}" != "x" ]; then
    ipaddr6=$(ip -6 addr show dev "${INT}" up scope global | grep inet6 | head -1 | awk '{print $2}' | cut -d / -f 1)
    if [ "x$ipaddr6" != "x" ]; then
	echo "ipaddress6_default=$ipaddr6"
    fi
fi
