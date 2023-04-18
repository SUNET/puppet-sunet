#!/busybox/sh

# This script creates a new CA and self-signed etcd cert everytime it runs.
# Since the overwritten files are then supplied to etcd and knubbis-fleetlock
# this is fine and we dont need to have a bunch of "do not verify TLS" flags
# everywhere. This also means there is no reason to store the CA private key
# anywhere, since it is never used again.

# Generate certs on tmpfs, the files we need to save will be copied to volume
# directories
cd /work || exit 1

cfssl gencert -initca /cert-bootstrap/ca.json | cfssljson -bare ca
cfssl gencert -ca ca.pem -ca-key ca-key.pem /cert-bootstrap/csr.json | cfssljson -bare etcd

# We need the CA public key for knubbis-fleetlock and etcdctl invocations
cp ca.pem /cert-bootstrap-ca

# We need private and public key for the etcd server
cp etcd.pem /cert-bootstrap-etcd
cp etcd-key.pem /cert-bootstrap-etcd
