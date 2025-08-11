#!/bin/bash

cephadm bootstrap \
    --mon-ip "<%= @facts['networking']['ip'] %>" \
    --ssh-user root \
    --ssh-private-key /root/.ssh/id_ed25519_adm \
    --ssh-public-key /root/.ssh/id_ed25519_adm.pub \
    --allow-fqdn-hostname \
    --allow-overwrite 
