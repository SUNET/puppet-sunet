#!/bin/bash

cephadm bootstrap \
    --mon-ip "<%= @facts['networking']['ip'] %>" \
    --ssh-user root \
    --ssh-private-key /root/.ssh/id_ed25519_adm \
    --ssh-public-key /root/.ssh/id_ed25519_adm.pub \
    --allow-overwrite 
cephadm shell ceph cephadm get-pub-key > /etc/ceph/ceph.pub
cephadm shell ceph config-key get mgr/cephadm/ssh_identity_key > /etc/ceph/ceph.key
chmod 600 /etc/ceph/ceph.key
cephadm shell ceph cephadm get-ssh-config > /etc/ceph/ssh_config
