#!/usr/bin/env bash
# Backup etcd backend for knubbis-fleetlock standalone service

if ! etcd_container_id=$(docker inspect --format="{{.Id}}" knubbis-fleetlock_standalone_etcd_1); then
   echo "docker inspect failed"
   exit 1
fi

if [ -z "$etcd_container_id" ]; then
    echo "empty return value from docker inspect"
    exit 1
fi

docker exec "$etcd_container_id" etcdctl \
    --cacert=/cert-bootstrap-ca/ca.pem \
    --endpoints=https://etcd:2379 \
    --cert=/cert-bootstrap-client-root/root.pem \
    --key=/cert-bootstrap-client-root/root-key.pem \
    snapshot save /etcd-backup/snapshot.db
