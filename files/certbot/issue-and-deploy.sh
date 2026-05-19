#!/usr/bin/env bash

set -euo pipefail

export RENEWED_LINEAGE="/etc/letsencrypt/live/${1}"
export NO_RELOAD=1

# Don't expand the glob to itself if no matching hooks
# Not all services do need hooks
shopt -s nullglob
for hook in /etc/letsencrypt/renewal-hooks/deploy/*; do
	echo "Running deploy hook ${hook} for ${1}."
	"${hook}"
done
