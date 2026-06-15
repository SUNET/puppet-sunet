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
command -v mariadb-backup >/dev/null || {
    echo "mariadb-backup not found" >&2
    exit 1
}

now="$(date +%Y-%m-%dT%H.%M.%S)"
dir_date="$(date +%Y/%m/%d)"

stream_name="mariadb-stream-${now}.gz"
dump_name="mariadb-dump-${now}.sql.gz"
backup_dir="/backups/${dir_date}"
mkdir -p "${backup_dir}"

buopts="--slave-info --safe-slave-backup"
dumpopts="--dump-slave"
${CMD} -p"${MYSQL_ROOT_PASSWORD}" -e "stop slave"
mariadb-backup --backup ${buopts} -u root -p"${MYSQL_ROOT_PASSWORD}" --stream=xbstream | gzip >"${backup_dir}/${stream_name}"
${DUMPCMD} --all-databases --single-transaction --routines --events --triggers --quick ${dumpopts} -u root -p"${MYSQL_ROOT_PASSWORD}" | gzip >"${backup_dir}/${dump_name}"
${CMD} -p"${MYSQL_ROOT_PASSWORD}" -e "start slave"
