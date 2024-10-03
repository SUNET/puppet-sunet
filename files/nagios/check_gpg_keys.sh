#!/usr/bin/env bash

set -uo pipefail

if [ $# -ne 1 ]; then
	echo "UNKOWN: A directory is required as \$1"
	exit 3
fi

args=("$@")
DIRECTORY=${args[0]}

if [ ! -d "${DIRECTORY}" ]; then
	echo "UNKOWN: Unknown directory (${DIRECTORY})"
	exit 3
fi

WARNING=$(date --date="+ 14 days" +%s)
CRITICAL=$(date --date="+ 7 days" +%s)

CRIT=0
WARN=0

EXPIRING=()
INVALIDS=()
INFINITIVES=()

NUM_KEYS=0

PREFIX="OK"
EXIT=0

TMPDIR=$(mktemp -d)
export GNUPGHOME="${TMPDIR}"

for key in "${DIRECTORY}"/*.pub; do
	((NUM_KEYS++))

	if ! pub_keys=$(gpg --fixed-list-mode --with-colons --show-keys "${key}" 2>/dev/null | grep -e '^pub:'); then
		INVALIDS+=("${key}")
		continue
	fi

	# Only allow one public key per file
	if [ "$(echo "${pub_keys}" | wc -l)" -ne 1 ]; then
		INVALIDS+=("${key}")
		continue
	fi

	expirey_date=$(echo "${pub_keys}" | cut -d : -f 7)

	if [ -z "${expirey_date}" ]; then
		INFINITIVES+=("${key}")
		((WARN++))
		continue
	elif ! echo "${expirey_date}" | grep -qP '^\d{10}$'; then
		echo "Warning: Can't parse ${key} for validity"
		((WARN++))
		INVALIDS+=("${key}")
		continue
	fi

	fingerprint=$(gpg --fixed-list-mode --with-colons --show-keys "${key}" 2>/dev/null | grep -A1 -e '^pub:' | grep -e '^fpr' | cut -d : -f 10)
	filename=$(basename "${key}")
	# Only allow files with the long fingerprint as suffix. E.g
	# jocar-13376BF892B5871181A218E9BE4EC2EEADF2C31B.pub
	if ! echo "${filename}" | grep -qP "^[^-]*-${fingerprint}.pub$"; then
		((WARN++))
		INVALIDS+=("${key}")
	fi

	if [ "${expirey_date}" -lt "${CRITICAL}" ]; then
		((CRIT++))
		EXPIRING+=("${key}")
	elif [ "${expirey_date}" -lt "${WARNING}" ]; then
		((WARN++))
		EXPIRING+=("${key}")
	fi
done

NUM_EXPIRING=${#EXPIRING[@]}
NUM_INVALID=${#INVALIDS[@]}
NUM_INFINITIVE=${#INFINITIVES[@]}

if [ "${CRIT}" -ne 0 ]; then
	PREFIX="CRITICAL"
	EXIT=2
elif [ "${WARN}" -ne 0 ]; then
	PREFIX="WARNING"
	EXIT=1
elif [ "$NUM_INVALID" -ne 0 ]; then
	PREFIX="WARNING"
	EXIT=1
fi

NON_OK_STRING=()
if [ "${NUM_EXPIRING}" -ne 0 ]; then
	NON_OK_STRING+=("Expiring/expired GPG keys (${NUM_EXPIRING}): ${EXPIRING[*]}")
fi

if [ "${NUM_INVALID}" -ne 0 ]; then
	NON_OK_STRING+=("Invalid GPG keys (${NUM_INVALID}): ${INVALIDS[*]}")
fi

if [ "${NUM_INFINITIVE}" -ne 0 ]; then
	NON_OK_STRING+=("GPG keys without expiration (${NUM_INVALID}): ${INFINITIVES[*]}")
fi

NON_OK_OUTPUT=""
for string in "${NON_OK_STRING[@]}"; do
	if [ -z "$NON_OK_OUTPUT" ]; then
		NON_OK_OUTPUT="${string}"
	else
		NON_OK_OUTPUT="${NON_OK_OUTPUT}, ${string}"
	fi
done

OUTPUT_STRING="No GPG keys are about to expire"
if [ -n "${NON_OK_OUTPUT}" ]; then
	OUTPUT_STRING=${NON_OK_OUTPUT}
fi

rm -rf "${TMPDIR}"

echo "${PREFIX}: ${OUTPUT_STRING} | expiring_keys=${NUM_EXPIRING} invalid_keys=${NUM_INVALID} infinite_keys=${NUM_INFINITIVE} total_keys=${NUM_KEYS}"
exit "${EXIT}"
