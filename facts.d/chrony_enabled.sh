#!/bin/sh

enabled="no"

if [ -f /etc/sunet-chrony-opt-in ]; then
    enabled="yes"
fi

if [ -r /etc/os-release ]; then
    . /etc/os-release
fi
if [ "${ID:-}" = almalinux ]; then
    enabled=yes
elif command -v lsb_release >/dev/null; then
    vendor=$(lsb_release -is)
    version=$(lsb_release -rs)
    test "$vendor" = "Debian" && dpkg --compare-versions "${version}" "ge" "12" && enabled="yes"
    test "$vendor" = "Ubuntu" && dpkg --compare-versions "${version}" "ge" "23.04" && enabled="yes"
fi

echo "sunet_chrony_enabled=${enabled}"
