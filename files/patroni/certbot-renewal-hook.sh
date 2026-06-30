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
CERT_DIR="/opt/patroni/certs"
CERT_DST="${CERT_DIR}/cert.pem"
KEY_DST="${CERT_DIR}/privkey.pem"
CHAIN_DST="${CERT_DIR}/chain.pem"
CONTAINER_NAME="patroni"

# patroni runtime UID/GID (inside container)
PATRONI_UID=999
PATRONI_GID=999

# Restrict default permissions for any files created by this script
umask 077

# === Ensure directory exists ===
install -d -m 755 "${CERT_DIR}"

# === Copy certs to temp files ===
cp "${RENEWED_LINEAGE}/fullchain.pem" "${CERT_DIR}/cert.pem.tmp"
cp "${RENEWED_LINEAGE}/privkey.pem"   "${CERT_DIR}/privkey.pem.tmp"
cp "${RENEWED_LINEAGE}/chain.pem"   "${CERT_DIR}/chain.pem.tmp"

# Set correct permissions on temp files before swapping
chown ${PATRONI_UID}:${PATRONI_GID} "${CERT_DIR}"/*.tmp
chmod 644 "${CERT_DIR}"/cert.pem.tmp
chmod 600 "${CERT_DIR}"/privkey.pem.tmp
chmod 644 "${CERT_DIR}"/chain.pem.tmp

# Atomically swap into place
mv "${CERT_DIR}/cert.pem.tmp" "${CERT_DST}"
mv "${CERT_DIR}/privkey.pem.tmp" "${KEY_DST}"
mv "${CERT_DIR}/chain.pem.tmp" "${CHAIN_DST}"

# === Defensive stat check (host-safe) ===
KEY_UID="$(stat -c %u "${KEY_DST}")"
KEY_MODE="$(stat -c %a "${KEY_DST}")"

if [[ "${KEY_UID}" -ne "${PATRONI_UID}" ]] || [[ "${KEY_MODE}" != 600 ]]; then
	echo "ERROR: Incorrect ownership or permissions on ${KEY_DST}" >&2
	exit 1
fi

# Send sighup to re-read config and certs
pkill -HUP -fx '/usr/bin/python3 /patroni.py patroni.yml'

echo "Patroni TLS certificates successfully updated"
