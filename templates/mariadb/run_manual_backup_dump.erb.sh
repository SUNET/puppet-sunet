#!/bin/bash

dump_name="mariadb-dump-$(date +%Y-%m-%dT%H.%M.%S).sql.gz"
dump_args="--all-databases --single-transaction --master-data=2"

if docker exec -t mariadb-db-1 sh -c 'command -v mariadb' &>/dev/null; then
    CMD="mariadb"
else
    CMD="mysql"
fi

if docker exec -t mariadb-db-1 sh -c 'command -v mariadb-dump' &>/dev/null; then
    DUMPCMD="mariadb-dump"
else
    DUMPCMD="mysqldump"
fi


# Replication slave priv was not in backup user creation script previously
docker exec mariadb-db-1 "${CMD}" -u root -p'<%= @mariadb_root_password %>' -e "GRANT REPLICATION SLAVE ON *.* TO 'backup'@'%'"
echo "Running backup as root user"
docker exec -u root mariadb-db-1 bash -c "${DUMPCMD} ${dump_args} | gzip >\"/backups/${dump_name}\""
