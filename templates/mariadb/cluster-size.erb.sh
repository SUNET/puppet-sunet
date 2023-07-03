#!/bin/bash

docker exec mariadb_db_1 mysql -u root -p'<%= @mysql_root_password %>' -N -B -e "show status like 'wsrep_cluster_size'"
