#!/bin/bash

dump_name="mariadb-dump-$(date +%Y-%m-%dT%H.%M.%S).sql.gz"
dump_args="--all-databases --single-transaction --master-data=2"

# Replication slave priv was not in backup user creation script previously
mysql -e "GRANT REPLICATION SLAVE ON *.* TO 'backup'@'%'"
echo "Running backup as root user"
mkdir -p /opt/backups
mysqldump "${dump_args}" | gzip >"/opt/backups/${dump_name}"
