#!/bin/bash

set -euo pipefail

if command -v mariadb &>/dev/null; then
    CMD="mariadb"
else
    CMD="mysql"
fi
if command -v mariadb-dump &>/dev/null; then
    DUMPCMD="mariadb-dump"
else
    DUMPCMD="mysqldump"
fi

stream_name="mariadb-stream-$(date +%Y-%m-%dT%H.%M.%S).gz"
dump_name="mariadb-dump-$(date +%Y-%m-%dT%H.%M.%S).sql.gz"
backup_dir="/backups/$(date +%Y/%m/%d)"
mkdir -p "${backup_dir}"

buopts="--slave-info --safe-slave-backup"
dumpopts="--dump-slave"
${CMD} -p"${MYSQL_ROOT_PASSWORD}" -e "stop slave"
mariadb-backup --backup ${buopts} -u root -p"${MYSQL_ROOT_PASSWORD}" --stream=xbstream | gzip >"${backup_dir}/${stream_name}"
${DUMPCMD} --all-databases --single-transaction ${dumpopts} -u root -p${MYSQL_ROOT_PASSWORD} | gzip >"${backup_dir}/${dump_name}"
${CMD} -p${MYSQL_ROOT_PASSWORD} -e "start slave"
