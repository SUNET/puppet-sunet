#!/bin/bash

cephadm bootstrap \
    --mon-ip "<%= @facts['networking']['ip'] %>" \
    --ssh-user root \
    --allow-overwrite \
    --output-dir /etc/ceph
