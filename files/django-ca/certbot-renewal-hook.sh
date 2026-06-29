#!/usr/bin/env bash
set -euo pipefail

# === Sanity checks ===
if [ -z "${RENEWED_LINEAGE:-}" ]; then
	echo "ERROR: RENEWED_LINEAGE not set (not running from certbot?)" >&2
	exit 1
fi

# === Configuration ===
CERT_DIR="/opt/djangoca/certs"
KEY_DST="${CERT_DIR}/privkey.pem"
FULLCHAIN_DST="${CERT_DIR}/fullchain.pem"

# nginx runtime UID/GID (inside container)
NGINX_UID=33
NGINX_GID=33

# Restrict default permissions for any files created by this script
umask 077

# === Ensure directory exists ===
install -d -m 755 "${CERT_DIR}"

# === Copy certs to temp files ===
cp "${RENEWED_LINEAGE}/fullchain.pem" "${CERT_DIR}/fullchain.pem.tmp"
cp "${RENEWED_LINEAGE}/privkey.pem" "${CERT_DIR}/privkey.pem.tmp"

# Set correct permissions on temp files before swapping
chown ${NGINX_UID}:${NGINX_GID} "${CERT_DIR}"/*.tmp
chmod 644 "${CERT_DIR}"/fullchain.pem.tmp
chmod 600 "${CERT_DIR}"/privkey.pem.tmp

# Atomically swap into place
mv "${CERT_DIR}/privkey.pem.tmp" "${KEY_DST}"
mv "${CERT_DIR}/fullchain.pem.tmp" "${FULLCHAIN_DST}"

# === Defensive stat check (host-safe) ===
KEY_UID="$(stat -c %u "${KEY_DST}")"
KEY_MODE="$(stat -c %a "${KEY_DST}")"

if [ "${KEY_UID}" -ne "${NGINX_UID}" ] || [ "${KEY_MODE}" != 600 ]; then
	echo "ERROR: Incorrect ownership or permissions on ${KEY_DST}" >&2
	exit 1
fi

docker exec -it django-ca-nginx nginx -s reload

echo "NGINX TLS certificates successfully updated"
