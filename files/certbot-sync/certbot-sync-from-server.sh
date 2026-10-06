#!/usr/bin/env bash

set -eu

basedir="/opt/certbot-sync"
syncdir="$basedir/letsencrypt"
hookdir="$basedir/renewal-hooks/deploy"

config=${basedir}/conf/certbot-sync-from-server.source
if [[ -f "${config}" ]]; then
	# shellcheck source=/dev/null
	. ${config}
else
	echo "No config (${config}) found!"
	exit 1
fi

bootstrap=0
if [[ ! -d $syncdir/live ]]; then
	bootstrap=1
fi

if [[ "${bootstrap}" == 1 ]]; then
	targetdir=$syncdir
else
	targetdir=$(mktemp -d /tmp/certbot_sync.XXXXX)
fi

# Only ever sync the live/ tree out of the export dir.
mkdir -p "${targetdir}/live"
if [[ "${CERTBOT_SYNC_SERVER}" = "$(hostname -f)" ]]; then
	rsync -az -v /opt/certbot-sync/export/live/ "${targetdir}/live/"
else
	rsync -e "ssh -i $HOME/.ssh/id_certbot_sync_client" -az -v root@"${CERTBOT_SYNC_SERVER}":live/ "${targetdir}/live/"
fi

# With default-closed exporting the live/ dir can be empty; don't let the glob
# expand to itself and produce a bogus "*" cert. Also covers the hook loop below.
shopt -s nullglob

certs_to_deploy=()
for file_system_entity in "${targetdir}"/live/*; do
	basename=$(basename "${file_system_entity}")
	if [[ "$basename" == "README" ]]; then
		continue
	fi
	# Everthing is new - deploy all!
	if [[ "${bootstrap}" == 1 ]]; then
		certs_to_deploy+=("${basename}")
	else
		# Cert exists…
		if [[ -d "$syncdir/live/${basename}" ]]; then
			# … but is it changed?
			if ! cmp -s "$syncdir/live/${basename}/fullchain.pem" "${targetdir}/live/${basename}/fullchain.pem"; then
				# Yes, changed! - deploy!
				certs_to_deploy+=("${basename}")
			fi
		else
			# Cert is new - better deploy
			certs_to_deploy+=("${basename}")
		fi
	fi
done

if [[ "${bootstrap}" == 0 ]]; then
	rsync -av --delete "${targetdir}/" $syncdir
	rm -vrf "${targetdir}"
fi

# Not all services need hooks; nullglob (set above) keeps this loop empty then.
for cert in "${certs_to_deploy[@]}"; do
	for hook in "$hookdir"/*; do
		echo "Running deploy hook ${hook} for ${cert}."
		RENEWED_LINEAGE="$syncdir/live/${cert}" "${hook}"
	done
done
