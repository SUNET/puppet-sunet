#!/bin/bash

if docker exec -t mariadb-db-1 sh -c 'command -v mariadb' &>/dev/null; then
    CMD="mariadb"
else
    CMD="mysql"
fi
six_hours_ago=$(date -d "6 hours ago" "+%Y-%m-%d %H:%M:%S")
docker exec mariadb-db-1 "${CMD}" -u root -p'<%= @mariadb_root_password %>' -N -B -e "PURGE BINARY LOGS BEFORE '${six_hours_ago}'"
