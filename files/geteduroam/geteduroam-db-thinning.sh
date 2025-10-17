#!/usr/bin/env bash

for colum in expires revoked; do
	docker exec mariadb-db-1 mysql -p"$(puppet lookup --render-as s mariadb_root_password 2>/dev/null)" geteduroam -e "delete from realm_signing_log WHERE ${colum} <= DATE_SUB(NOW(),INTERVAL 6 MONTH);"
	sleep 10
done
