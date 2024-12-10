#!/bin/bash

cephadm bootstrap \
    --mon-ip "<%= @facts['networking']['ip'] %>" \
    --ssh-user root \
    --allow-overwrite 
cephadm shell ceph cephadm get-pub-key > /etc/ceph/ceph.pub
cephadm shell ceph config-key get mgr/cephadm/ssh_identity_key > /etc/ceph/ceph.key
chmod 600 /etc/ceph/ceph.key
