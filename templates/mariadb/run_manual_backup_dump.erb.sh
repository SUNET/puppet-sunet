#!/bin/bash

dump_name="mariadb-dump-$(date +%Y-%m-%dT%H.%M.%S).sql.gz"
dump_args="--all-databases --single-transaction --master-data=2"

# Replication slave priv was not in backup user creation script previously
docker exec mariadb-db-1 mysql -u root -p'<%= @mariadb_root_password %>' -e "GRANT REPLICATION SLAVE ON *.* TO 'backup'@'%'"
echo "Running backup as root user"
docker exec mariadb-db-1 bash -c "mysqldump ${dump_args} | gzip >\"/backups/${dump_name}\""
