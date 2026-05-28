#!/bin/bash
#

# Serial of the nagiosmonitor partition
SERIAL_TUG=1429929129936
SERIAL_STHB=1428350538482
SERIAL_LLA=1429933786537
SERIAL_DCOA=1621911929454
SERIAL_DCOB=1620838580408
SERIAL_TUGLAB=1428432029163

ROOT_CERT=/usr/safenet/lunaclient/cert/safenet-root.pem
CHALLANGE=1234567890
PASSFILE=/root/hsm-partition-pin

# shellcheck source=/dev/null
source $PASSFILE

case "$1" in
tug)
	SERIAL=$SERIAL_TUG
	;;
sthb)
	SERIAL=$SERIAL_STHB
	;;
lla)
	SERIAL=$SERIAL_LLA
	;;
dcoa)
	SERIAL=$SERIAL_DCOA
	;;
dcob)
	SERIAL=$SERIAL_DCOB
	;;
tuglab)
	SERIAL=$SERIAL_TUGLAB
	;;
*)
	echo "Usage: $0 <tug|shtb|lla|dcoa|dcob|tuglab>"
	exit 1
	;;
esac

SLOT=$(/usr/safenet/lunaclient/bin/vtl verify | grep "$SERIAL" | awk '{print $1}')

if [ -z "${SLOT}" ] ; then
	echo "Warning: Could not find correct SLOT - $SLOT"
	exit 1
fi

HSM=$(/usr/safenet/lunaclient/bin/cmu verifyhsm -challenge="$CHALLANGE" -rootcert="$ROOT_CERT" -slot "$SLOT" -password="$PIN" 2>&1)
EXITCODE=$?

if [ $EXITCODE -ne 0 ]; then
	echo "CRITICAL - HSM NOT OK"
	echo "$HSM"
	exit 2
fi

echo "OK - HSM OK"
exit 0
