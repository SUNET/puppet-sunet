#!/bin/sh
#
# FIXME: Might have to handle hosts with more than one IP-address on the "outside"
# 	 interface, this script *should* pick one and still work, but ...

INT=`route |grep default|awk 'END {print $NF}'`

ipaddr4=$(ifconfig $INT | grep "inet addr" | head -1 | cut -d ':' -f 2 | cut -d ' ' -f 1)
if [ "x$ipaddr4" != "x" ]; then
    echo "ipaddress_default=$ipaddr4"
fi

ipaddr6=$(ip -6 addr show dev $INT up scope global | grep inet6 | head -1 | awk '{print $2}' | cut -d / -f 1)
if [ "x$ipaddr6" != "x" ]; then
    echo "ipaddress6_default=$ipaddr6"
fi
