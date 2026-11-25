#!/bin/sh

enabled="no"

if [ -f /etc/sunet-nftables-opt-in ]; then
    enabled="yes"
fi

if [ -r /etc/os-release ]; then
    . /etc/os-release
fi
if [ "${ID:-}" = almalinux ]; then
    enabled=yes
    if systemctl is-active --quiet firewalld.service || systemctl is-enabled --quiet firewalld.service 2>/dev/null; then
        echo 'sunet_firewalld_enabled=yes'
    fi
elif command -v lsb_release >/dev/null; then
    vendor=$(lsb_release -is)
    version=$(lsb_release -rs)
    test "$vendor" = "Debian" && dpkg --compare-versions "${version}" "ge" "11" && enabled="yes"
    test "$vendor" = "Ubuntu" && dpkg --compare-versions "${version}" "ge" "22.04" && enabled="yes"
fi

echo "sunet_nftables_enabled=${enabled}"

# old name, kept for backwards compatibility
echo "sunet_nftables_opt_in=${enabled}"
