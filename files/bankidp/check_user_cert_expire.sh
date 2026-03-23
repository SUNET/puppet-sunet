#!/bin/sh

#It is a changed version of the original https://github.com/sergioshev/nagios-plugins/blob/master/check_cert_expire

set -u
set -e

#ok if cert has minimum 50 days of validity or more, warns if less than 50 days but more than two weeks left, critical if less than two weeks left or already is expired
ok=4320000
warn=1209600

usage() {
	echo "Usage: $0 <certfile>" >&2
	exit 3
}

if [ "$#" != 1 ]; then
	usage
fi

cert="$1"

if ! [ -f "$cert" ]; then
	echo "Infra cert file ($cert) does not exist" >&2
	exit 0
fi

expires=$(openssl x509 -enddate -noout -passin pass:qwerty123 <"$cert")

if openssl x509 -checkend "$ok" -noout -passin pass:qwerty123 <"$cert" >/dev/null; then
	echo "OK: $expires"
	exit 0
fi

if openssl x509 -checkend "$warn" -noout -passin pass:qwerty123 <"$cert" >/dev/null; then
	echo "WARNING: $expires"
	exit 2
fi
echo "CRITICAL: $expires"
exit 2
