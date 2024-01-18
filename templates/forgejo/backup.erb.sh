#!/bin/bash
backup_dir="/opt/forgejo/backups"
backup_bucket="backups-test"
if [[ $(hostname) =~ prod ]]; then
  backup_bucket="backups"
fi

echo "Starting backup: $(date)"
/usr/bin/docker exec forgejo  bash -c "cd ${backup_dir} && gitea dump -c /opt/forgejo/config/app.ini --tempdir ${backup_dir} && cp -v /opt/forgejo/data/forgejo.db ${backup_dir}/forgejo.$(date -Iminutes).db"
status=${?}
if [[ ${status} -ne 0 ]]; then
  echo "Backup failed: $(date)"
  second_status=0
else
  echo "Backup done: $(date)"
  echo "Moving backups to remote: $(date)"
  PASSPHRASE="<%= @platform_sunet_se_gpg_password %>" duplicity --encrypt-key=<%= @smtp_user %>@sunet.se \
    --full-if-older-than 1M --asynchronous-upload "${backup_dir}" "rclone://backups:/${backup_bucket}"
  second_status=${?}
  if [[ ${second_status} -eq 0 ]]; then
    echo "Cleaning up old backups: $(date)"
    find "${backup_dir}" -mtime +30 -delete
  else
    echo "Backup to remote failed: $(date)"
  fi
fi
total_status=$(( status + second_status ))
exit ${total_status}
