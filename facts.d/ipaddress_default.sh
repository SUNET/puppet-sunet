#!/bin/bash
#
# FIXME: Might have to handle hosts with more than one IP-address on the "outside"
# 	 interface, this script *should* pick one and still work, but ...

INT=`route |grep default|awk 'END {print $NF}'`

echo -n "ipaddress_default="
ifconfig $INT | grep "inet addr" | cut -d ':' -f 2 | cut -d ' ' -f 1

