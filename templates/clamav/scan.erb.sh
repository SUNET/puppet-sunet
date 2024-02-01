#!/bin/bash

num_infected=$(clamdscan --multiscan --fdpass  /* | awk -F: '/Infected files:/{print $2}' | tr -d ' ')

if [[ ${num_infected} -gt 0 ]]; then
    echo "ClamAV found ${num_infected} infected files"
    exit 1
fi

echo "ClamAV found no infected files"
exit 0

