#!/bin/sh

if systemctl list-unit-files docker.service | grep docker -q; then
    echo "docker_service_exists=yes"
else
    echo "docker_service_exists=no"
fi

