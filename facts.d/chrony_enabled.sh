#!/bin/sh

enabled="no"

if [ -f /etc/sunet-chrony-opt-in ]; then
    enabled="yes"
fi

vendor=$(lsb_release -is)
version=$(lsb_release -rs)
test "$vendor" = "Debian" && dpkg --compare-versions "${version}" "ge" "12" && enabled="yes"
test "$vendor" = "Ubuntu" && dpkg --compare-versions "${version}" "ge" "23.04" && enabled="yes"

echo "sunet_chrony_enabled=${enabled}"
