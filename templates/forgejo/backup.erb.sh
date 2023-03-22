#!/bin/bash

echo "Starting backup: $(date)"
docker-compose -f /opt/forgejo/docker-compose.yaml exec -ti forgejo  bash -c 'cd /opt/forgejo/backups && gitea dump -c /opt/forgejo/config/app.ini --tempdir /opt/forgejo/backups'
status=${?}
echo "Backup done: $(date)"
exit ${status}
