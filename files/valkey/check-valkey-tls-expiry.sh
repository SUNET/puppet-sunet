#!/bin/bash

# check_valkey_tls_cert.sh
#
# NRPE/Nagios plugin to check Valkey TLS certificate expiry on all
# local cluster ports discovered from:
#
#   valkey-connect --cluster-nodes
#
# Thresholds:
#   WARNING  = 14 days
#   CRITICAL = 7 days
#
# Exit codes:
#   0 = OK
#   1 = WARNING
#   2 = CRITICAL
#   3 = UNKNOWN

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

WARNING_DAYS=14
CRITICAL_DAYS=7

CERT="/opt/valkey/cert/cert.pem"
KEY="/opt/valkey/cert/privkey.pem"
CAFILE="/etc/ssl/certs/infra-2-prod.crt"

#
# Get cluster information
#
cluster_nodes="$(valkey-connect --cluster-nodes 2>/dev/null)"

if [ -z "$cluster_nodes" ]; then
    echo "UNKNOWN - Failed to retrieve cluster nodes"
    exit $STATE_UNKNOWN
fi

#
# Determine local FQDN from the "myself" entry
#
local_fqdn=$(
    echo "$cluster_nodes" |
    awk '/myself/ {
        split($2,a,",")
        print a[2]
        exit
    }'
)

if [ -z "$local_fqdn" ]; then
    echo "UNKNOWN - Failed to determine local FQDN"
    exit $STATE_UNKNOWN
fi

#
# Find all ports belonging to this local FQDN
#
ports=$(
    echo "$cluster_nodes" |
    awk -v fqdn="$local_fqdn" '
    $2 ~ "," fqdn "$" {
        split($2,a,":")
        split(a[2],b,"@")
        print b[1]
    }' |
    sort -nu
)

if [ -z "$ports" ]; then
    echo "UNKNOWN - No local ports found"
    exit $STATE_UNKNOWN
fi

worst_state=$STATE_OK
status_text=""
perfdata=""

for port in $ports
do
    enddate=$(
        openssl s_client \
            -connect "${local_fqdn}:${port}" \
            -servername "${local_fqdn}" \
            -cert "${CERT}" \
            -key "${KEY}" \
            -CAfile "${CAFILE}" \
            </dev/null 2>/dev/null |
        openssl x509 -noout -enddate 2>/dev/null
    )

    if [ -z "$enddate" ]; then
        status_text="${status_text}port ${port}: unable to read certificate; "

        if [ $worst_state -lt $STATE_UNKNOWN ]; then
            worst_state=$STATE_UNKNOWN
        fi

        continue
    fi

    expiry_date="${enddate#notAfter=}"

    expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null)

    if [ $? -ne 0 ]; then
        status_text="${status_text}port ${port}: unable to parse certificate date; "

        if [ $worst_state -lt $STATE_UNKNOWN ]; then
            worst_state=$STATE_UNKNOWN
        fi

        continue
    fi

    now_epoch=$(date +%s)
    days_remaining=$(( (expiry_epoch - now_epoch) / 86400 ))

    status_text="${status_text}port ${port}: ${days_remaining} days (${expiry_date}); "

    perfdata="${perfdata} port_${port}=${days_remaining};${WARNING_DAYS};${CRITICAL_DAYS}"

    if [ "$days_remaining" -le "$CRITICAL_DAYS" ]; then
        [ $worst_state -lt $STATE_CRITICAL ] && worst_state=$STATE_CRITICAL

    elif [ "$days_remaining" -le "$WARNING_DAYS" ]; then
        [ $worst_state -lt $STATE_WARNING ] && worst_state=$STATE_WARNING
    fi
done

case $worst_state in
    $STATE_OK)
        echo "OK - ${status_text}|${perfdata}"
        ;;
    $STATE_WARNING)
        echo "WARNING - ${status_text}|${perfdata}"
        ;;
    $STATE_CRITICAL)
        echo "CRITICAL - ${status_text}|${perfdata}"
        ;;
    *)
        echo "UNKNOWN - ${status_text}|${perfdata}"
        ;;
esac

exit $worst_state
