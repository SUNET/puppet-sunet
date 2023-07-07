#!/bin/bash
six_hours_ago=$(date -d "6 hours ago" "+%Y-%m-%d %H:%M:%S")
mysql -u root -p'<%= @mysql_root_password %>' -N -B -e "PURGE BINARY LOGS BEFORE '${six_hours_ago}'"
