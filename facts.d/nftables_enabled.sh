#!/bin/sh

enabled="no"

if [ -f /etc/sunet-nftables-opt-in ]; then
    enabled="yes"
fi

vendor=$(lsb_release -is)
version=$(lsb_release -rs)
test "$vendor" = "Debian" && dpkg --compare-versions "${version}" "ge" "11" && enabled="yes"
test "$vendor" = "Ubuntu" && dpkg --compare-versions "${version}" "ge" "22.04" && enabled="yes"

echo "sunet_nftables_enabled=${enabled}"

# old name, kept for backwards compatibility
echo "sunet_nftables_opt_in=${enabled}"
