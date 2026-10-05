#!/bin/bash
backup_dir="/opt/forgejo/backups"

echo "Starting backup: $(date)"
/usr/bin/docker exec forgejo  bash -c "cd ${backup_dir} && gitea dump -c /opt/forgejo/config/app.ini --tempdir ${backup_dir} && cp -v /opt/forgejo/data/forgejo.db ${backup_dir}/forgejo.$(date -Iminutes).db"
status=${?}
if [[ ${status} -ne 0 ]]; then
  echo "Backup failed: $(date)"
  exit 1
fi
