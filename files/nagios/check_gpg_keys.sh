#!/usr/bin/env bash

set -o pipefail

if [ -z "$1" ]; then
	echo "UNKOWN: A directory is required as \$1"
	exit 3
fi

DIRECTORY="$1"

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

NUM_KEYS=0
INFINITE_KEYS=0

PREFIX="OK"
EXIT=0

for key in "${DIRECTORY}"/*.pub; do
  ((NUM_KEYS++))

	if ! expirey_date=$(gpg --fixed-list-mode --with-colons --show-keys "${key}" 2>/dev/null | grep -e '^pub:' | cut -d : -f 7); then
		INVALIDS+=("${key}")
		continue
	fi
	if [ "$(echo "${expirey_date}" | wc -l)" -ne 1 ]; then
		INVALIDS+=("${key}")
		continue
	fi

	if [ -z "${expirey_date}" ]; then
    ((INFINITE_KEYS++))
		continue
	elif ! echo "${expirey_date}" | grep -qP '^\d{10}$'; then
		echo "Warning: Can't parse ${key} for validity"
    ((WARN++))
		INVALIDS+=("${key}")
		continue
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

if [ $CRIT -ne 0 ]; then
	PREFIX="CRITICAL"
	EXIT=1
elif [ $WARN -ne 0 ]; then
	PREFIX="WARNING"
	EXIT=2
elif [ "$NUM_INVALID" -ne 0 ]; then
	PREFIX="WARNING"
	EXIT=2
fi

NON_OK_STRING=()
if [ "${NUM_EXPIRING}" -ne 0 ]; then
	NON_OK_STRING+=("Expiring/expired gpg keys (${NUM_EXPIRING}): ${EXPIRING[*]}")
fi

if [ "${NUM_INVALID}" -ne 0 ]; then
	NON_OK_STRING+=("Invalid gpg keys (${NUM_INVALID}): ${INVALIDS[*]}")
fi

NON_OK_OUTPUT=""
for string in "${NON_OK_STRING[@]}"; do
	if [ -z "$NON_OK_OUTPUT" ]; then
		NON_OK_OUTPUT="${string}"
	else
		NON_OK_OUTPUT="${NON_OK_OUTPUT}, ${string}"
	fi
done

OUTPUT_STRING="No gpg keys are about to expire"
if [ -n "${NON_OK_OUTPUT}" ]; then
	OUTPUT_STRING=${NON_OK_OUTPUT}
fi

echo "${PREFIX}: ${OUTPUT_STRING} | expiring_keys=${NUM_EXPIRING} invalid_keys=${NUM_INVALID} infinite_keys=${INFINITE_KEYS} total_keys=${NUM_KEYS}"
exit "${EXIT}"
