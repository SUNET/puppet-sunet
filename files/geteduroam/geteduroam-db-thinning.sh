#!/usr/bin/env bash

for colum in expires revoked; do
  echo "working on ${colum}"
	docker exec mariadb-db-1 mysql -p"$(puppet lookup --render-as s mariadb_root_password 2>/dev/null)" geteduroam -e "delete from realm_signing_log WHERE ${colum} <= DATE_SUB(NOW(),INTERVAL 6 MONTH);SELECT ROW_COUNT();"
	sleep 10
done
