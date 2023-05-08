#!/bin/bash
if [ -x "/usr/local/libexec/cosmos-cron-wrapper" ]; then
    echo "cosmos_cron_wrapper_available=true"
fi

if [ -x "/usr/local/bin/scriptherder" ]; then
    echo "scriptherder_available=true"
fi

if [ -f "/etc/scriptherder/check/cosmos.ini" ]; then
    echo "local_cosmos_ini_available=true"
fi
