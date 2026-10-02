#!/usr/bin/env bash

set -euo pipefail

export RENEWED_LINEAGE="/etc/letsencrypt/live/${1}"
export NO_RELOAD=1

# certbot only runs the deploy hook directory on renewal, so this script stands in
# for it at issuing time - which means providing the same environment. The cert's
# SANs are the list certbot would have passed as RENEWED_DOMAINS.
RENEWED_DOMAINS="$(openssl x509 -noout -ext subjectAltName -in "${RENEWED_LINEAGE}/cert.pem" |
	tr ',' '\n' | sed -n 's/^[[:space:]]*DNS://p' | tr '\n' ' ')"
export RENEWED_DOMAINS

# Don't expand the glob to itself if no matching hooks
# Not all services do need hooks
shopt -s nullglob
for hook in /etc/letsencrypt/renewal-hooks/deploy/*; do
	echo "Running deploy hook ${hook} for ${1}."
	"${hook}"
done
