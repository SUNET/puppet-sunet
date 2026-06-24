#!/usr/bin/env bash
set -euo pipefail

# === Sanity checks ===
if [ -z "${RENEWED_LINEAGE:-}" ]; then
	echo "ERROR: RENEWED_LINEAGE not set (not running from certbot?)" >&2
	exit 1
fi

if [[ "$(basename "${RENEWED_LINEAGE}")" != "$(hostname -f)" ]]; then
	echo "NOTICE: Skipping certbot hook for non-hostname" >&2
	exit 0
fi

# === Configuration ===
CERT_DIR="/opt/etcd/cert"
CERT_DST="${CERT_DIR}/cert.pem"
KEY_DST="${CERT_DIR}/privkey.pem"
CHAIN_DST="${CERT_DIR}/chain.pem"

# === Ensure directory exists ===
install -d -m 700 "${CERT_DIR}"

# === Install public certificate ===
install -m 0644 \
	"${RENEWED_LINEAGE}/cert.pem" \
	"${CERT_DST}"

install -m 0644 \
	"${RENEWED_LINEAGE}/chain.pem" \
	"${CHAIN_DST}"

install -m 0600 \
	"${RENEWED_LINEAGE}/privkey.pem" \
	"${KEY_DST}"

echo "ETCD TLS certificates successfully updated"
