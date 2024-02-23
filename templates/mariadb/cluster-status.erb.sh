#!/bin/bash

docker exec mariadb-db-1 mysql -u root -p'<%= @mysql_root_password %>' -N -B -e "show status like 'wsrep_cluster_status'"
