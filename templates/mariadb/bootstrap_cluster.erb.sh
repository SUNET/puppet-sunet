#!/bin/bash

systemctl stop mariadb.service
galera_new_cluster
mysql < '/etc/mysql/02-backup_user.sql'

