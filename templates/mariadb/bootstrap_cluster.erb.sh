#!/bin/bash

MYSQL_ROOT_PASSWORD="<%= @mysql_root_password %>"
systemctl stop mariadb.service
galera_new_cluster
mysql -p"${MYSQL_ROOT_PASSWORD}" < '/etc/mysql/02-backup_user.sql'

