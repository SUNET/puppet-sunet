#!/bin/bash
#
# This finds (hopefully) the public interface based on default route

echo -n "interface_default="
route |grep default|awk 'END {print $NF}'

