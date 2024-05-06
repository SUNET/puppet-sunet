#!/busybox/sh

# This script creates a new CA and self-signed etcd cert everytime it runs.
# Since the overwritten files are then supplied to etcd and knubbis-fleetlock
# this is fine and we dont need to have a bunch of "do not verify TLS" flags
# everywhere. This also means there is no reason to store the CA private key
# anywhere, since it is never used again.

# Generate certs on tmpfs, the files we need to save will be moved to volume
# directories
cd /work || exit 1

# Generate CA
cfssl gencert -initca /cert-bootstrap/ca.json | cfssljson -bare ca

# Generate etcd server cert
cfssl gencert -config /cert-bootstrap/cfssl.json -profile server -ca ca.pem -ca-key ca-key.pem /cert-bootstrap/etcd.json | cfssljson -bare etcd

# Generate client certs
cfssl gencert -config /cert-bootstrap/cfssl.json -profile client -ca ca.pem -ca-key ca-key.pem /cert-bootstrap/root.json | cfssljson -bare root
cfssl gencert -config /cert-bootstrap/cfssl.json -profile client -ca ca.pem -ca-key ca-key.pem /cert-bootstrap/knubbis-fleetlock.json | cfssljson -bare knubbis-fleetlock

# We need the CA public key for knubbis-fleetlock and etcdctl invocations
mv ca.pem /cert-bootstrap-ca

# We need private and public key for the etcd server
mv etcd.pem /cert-bootstrap-etcd
mv etcd-key.pem /cert-bootstrap-etcd

# Store "root" client cert for etcdctl invocations
mv root.pem /cert-bootstrap-client-root
mv root-key.pem /cert-bootstrap-client-root

# Store "knubbis-fleetlock" client cert for knubbis-fleetlock server
mv knubbis-fleetlock.pem /cert-bootstrap-client-knubbis-fleetlock
mv knubbis-fleetlock-key.pem /cert-bootstrap-client-knubbis-fleetlock
