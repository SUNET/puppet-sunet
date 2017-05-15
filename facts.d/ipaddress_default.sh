#!/bin/sh
#
# FIXME: Might have to handle hosts with more than one IP-address on the "outside"
# 	 interface, this script *should* pick one and still work, but ...

INT=`route |grep default|awk 'END {print $NF}'`

# This command works on Ubuntu 16.04 and earlier (?)
ipaddr4=$(ifconfig $INT | grep "inet addr" | head -1 | cut -d ':' -f 2 | cut -d ' ' -f 1)
if [ "x$ipaddr4" = "x" ]; then
    # Try again with command that works on Ubuntu 16.10 and later (?)
    ipaddr4=$(ip -4 addr show dev "${INT}" up scope global | grep inet | head -1 | awk '{print $2}' | cut -d / -f 1)
fi

if [ "x$ipaddr4" != "x" ]; then
    echo "ipaddress_default=$ipaddr4"
fi

ipaddr6=$(ip -6 addr show dev "${INT}" up scope global | grep inet6 | head -1 | awk '{print $2}' | cut -d / -f 1)
if [ "x$ipaddr6" != "x" ]; then
    echo "ipaddress6_default=$ipaddr6"
fi
