#!/usr/bin/env bash
#
# certbot deploy hook, installed by sunet::certbot::sync::server.
#
# certbot runs this per renewed lineage with RENEWED_LINEAGE set. If the cert's
# domain is opted in as exportable in /etc/letsencrypt/acmedns.json, install the
# (dereferenced) cert files into /opt/certbot-sync/export/live/<name> for sync
# clients to fetch. Certs not marked exportable are kept out of (and removed
# from) the export dir.

set -eu

exportdir="/opt/certbot-sync/export"
acmedns="/etc/letsencrypt/acmedns.json"

lineage="${RENEWED_LINEAGE:-}"
if [[ -z "${lineage}" ]]; then
	echo "RENEWED_LINEAGE is not set - this script must be run as a certbot deploy hook."
	exit 1
fi
name="$(basename "${lineage}")"

# RENEWED_DOMAINS is a space separated list; also match SAN certs whose lineage
# name differs from the acmedns.json key.
read -r -a renewed_domains <<<"${RENEWED_DOMAINS:-}"

exportable="no"
for key in ${renewed_domains[@]}"; do
	[[ -z "${key}" ]] && continue
	if jq -e --arg k "${key}" '(.[$k].exportable // false) == true' "${acmedns}" >/dev/null 2>&1; then
		exportable="yes"
		break
	fi
done

dest="${exportdir}/live/${name}"

if [[ "${exportable}" != "yes" ]]; then
	echo "${name} is not marked exportable in ${acmedns}; ensuring it is not exported."
	rm -rf "${dest}"
	exit 0
fi

install -d -m 0700 "${exportdir}"
install -d -m 0700 "${exportdir}/live"
install -d -m 0700 "${dest}"

# install(1) follows the live/ -> archive/ symlinks and writes a real regular
# file at the destination, so clients receive plain files rather than symlinks.
# fullchain.pem is written last since clients key their "changed?" check off it.
for f in privkey cert chain fullchain; do
	install -m 0600 "${lineage}/${f}.pem" "${dest}/${f}.pem"
done

echo "Exported ${name} to ${dest}."
