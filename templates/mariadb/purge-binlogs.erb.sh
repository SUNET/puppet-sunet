#!/bin/bash
six_hours_ago=$(date -d "6 hours ago" "+%Y-%m-%d %H:%M:%S")
docker exec mariadb-db-1 mysql -u root -p'<%= @mariadb_root_password %>' -N -B -e "PURGE BINARY LOGS BEFORE '${six_hours_ago}'"
