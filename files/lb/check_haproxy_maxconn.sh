#!/bin/bash

# WARN and CRIT thresholds for connection usage (percentage)
WARN=80
CRIT=90

# NRPE exit status:
# 0 = OK, 1 = WARNING, 2 = CRITICAL, 3 = UNKNOWN
STATUS=0

# Output string returned to NRPE
OUTPUT=""

# Loop over all running docker containers that contain "haproxy" in the name
for c in $(docker ps --format '{{.Names}}' | grep haproxy); do

    # Query HAProxy stats socket for "show info"
    # This returns metrics like Maxconn, CurrConns, MaxconnReached, etc.
    info=$(docker exec "$c" sh -c 'echo "show info" | socat stdio /haproxy_control/stats')

    # Extract maximum allowed connections
    max=$(echo "$info" | awk -F': ' '/Maxconn:/ {print $2}')

    # Extract current number of active connections
    curr=$(echo "$info" | awk -F': ' '/CurrConns:/ {print $2}')

    # Extract number of times max connections have been reached
    max_reached=$(echo "$info" | awk -F': ' '/MaxconnReached:/ {print $2}')

    # If any critical value is missing or max is zero, return UNKNOWN
    if [[ -z "$max" || -z "$curr" || "$max" -eq 0 ]]; then
        OUTPUT+="UNKNOWN $c (no data) | "
        STATUS=3
        continue
    fi

    # Calculate connection usage percentage
    pct=$(( curr * 100 / max ))

    # --- CRITICAL conditions ---
    # 1. Connection usage above CRIT threshold
    # 2. MaxconnReached > 0 (HAProxy has hit the limit at least once)
    if (( pct >= CRIT )) || (( max_reached > 0 )); then
        OUTPUT+="CRIT $c ${pct}% (${curr}/${max}), MaxconnReached=${max_reached} | "
        STATUS=2

    # --- WARNING condition ---
    elif (( pct >= WARN )) && (( STATUS < 2 )); then
        OUTPUT+="WARN $c ${pct}% (${curr}/${max}), MaxconnReached=${max_reached} | "
        STATUS=1

    # --- OK condition ---
    else
        OUTPUT+="OK $c ${pct}% (${curr}/${max}), MaxconnReached=${max_reached} | "
    fi
done

# Print final output
echo "$OUTPUT"

# Exit with NRPE status
exit $STATUS
