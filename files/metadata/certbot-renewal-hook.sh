#!/usr/bin/env bash
set -euo pipefail

# === Sanity checks ===
if [[ -z "${RENEWED_LINEAGE:-}" ]]; then
	echo "ERROR: RENEWED_LINEAGE not set (not running from certbot?)" >&2
	exit 1
fi

if [[ "$(basename "${RENEWED_LINEAGE}")" != "$(hostname -f)" ]]; then
	echo "NOTICE: Skipping certbot hook for non-hostname" >&2
	exit 0
fi

# === Configuration ===
CERT_DIR="/opt/mdq_publisher/certs"
FULLCHAIN_DST="${CERT_DIR}/fullchain.pem"
KEY_DST="${CERT_DIR}/privkey.pem"

# service runtime UID/GID (inside container)
SERVICE_UID=0
SERVICE_GID=0

# Restrict default permissions for any files created by this script
umask 077

# === Ensure directory exists ===
install -d -m 755 "${CERT_DIR}"

# === Copy certs to temp files ===
cp "${RENEWED_LINEAGE}/fullchain.pem" "${CERT_DIR}/fullchain.pem.tmp"
cp "${RENEWED_LINEAGE}/privkey.pem"   "${CERT_DIR}/privkey.pem.tmp"

# Set correct permissions on temp files before swapping
chown ${SERVICE_UID}:${SERVICE_GID} "${CERT_DIR}"/*.tmp
chmod 644 "${CERT_DIR}"/fullchain.pem.tmp
chmod 600 "${CERT_DIR}"/privkey.pem.tmp

# Atomically swap into place
mv "${CERT_DIR}/fullchain.pem.tmp" "${FULLCHAIN_DST}"
mv "${CERT_DIR}/privkey.pem.tmp" "${KEY_DST}"

# Prevent reload when service is not fully installed.
# Like when issuing the cert for the first time.
if [ -n "${NO_RELOAD:-}" ]; then
	exit 0
fi

# Send sighup to re-read certs
pkill -HUP -fx '/mdq-publisher'
