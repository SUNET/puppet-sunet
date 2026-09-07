#!/bin/bash

set -eou pipefail

backupdir=/opt/backups
backuptime=$(date +%Y-%m-%d.%H)

# Steal credentials of off docker containers env, used in connection string below
# DOCKER_PG_LLVM_DEPS contains multiple values with tab(?) as delimiter…
# shellcheck disable=SC1090
source <(docker exec -u postgres postgres env | grep -v DOCKER_PG_LLVM_DEPS)

mkdir -p "${backupdir}"/{postgres,redis}

docker exec postgres pg_dumpall --clean --if-exists --no-password \
        --dbname "postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@localhost" \
       | gzip > "${backupdir}/postgres/postgres-${backuptime}.sql.gz"

cp /opt/mastodon_backend/redis/dump.rdb "${backupdir}/redis/redis-${backuptime}.rdb"

