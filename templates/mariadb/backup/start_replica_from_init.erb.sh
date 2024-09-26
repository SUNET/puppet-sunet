#!/usr/bin/env bash
mysql="mysql -u root -p${MYSQL_ROOT_PASSWORD}"
init_file='/backups/init.sql.gz'
if [[ -f ${init_file} ]]; then
	${mysql} -e "STOP SLAVE;RESET SLAVE;"
	master_command=$(zgrep 'CHANGE MASTER TO MASTER_LOG_FILE' ${init_file} | sed -e 's/^-- //' -e 's/;$//')
	master_command="${master_command}, MASTER_HOST='<%= @replicate_from %>', MASTER_USER='backup'"
	master_command="${master_command}, MASTER_PASSWORD='<%= @mariadb_backup_password%>', MASTER_SSL=1"
	master_command="${master_command}, MASTER_CONNECT_RETRY=20"
	zcat ${init_file} | ${mysql}
	${mysql} -e "${master_command}"
	${mysql} -e "START SLAVE"
	sleep 3s
	${mysql} -e "SHOW SLAVE STATUS\G"
fi

exit 0
