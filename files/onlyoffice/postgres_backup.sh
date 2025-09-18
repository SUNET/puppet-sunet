#!/usr/bin/env bash
#
# Simplistic postgres backup
#
set -e

BACKUPROOT=${BACKUPROOT-"/var/lib/postgresql/backup"}

if [ ! -d ${BACKUPROOT} ]; then
    echo "$0: Directory ${BACKUPROOT} does not exist - aborting."
    exit 1
fi

# keep ten runs worth of dumps
rm -rf ${BACKUPROOT}/postgres-dumpall.gz.10
test -f ${BACKUPROOT}/postgres-dumpall.gz.9 && mv ${BACKUPROOT}/postgres-dumpall.gz.9 ${BACKUPROOT}/postgres-dumpall.gz.10
test -f ${BACKUPROOT}/postgres-dumpall.gz.8 && mv ${BACKUPROOT}/postgres-dumpall.gz.8 ${BACKUPROOT}/postgres-dumpall.gz.9
test -f ${BACKUPROOT}/postgres-dumpall.gz.7 && mv ${BACKUPROOT}/postgres-dumpall.gz.7 ${BACKUPROOT}/postgres-dumpall.gz.8
test -f ${BACKUPROOT}/postgres-dumpall.gz.6 && mv ${BACKUPROOT}/postgres-dumpall.gz.6 ${BACKUPROOT}/postgres-dumpall.gz.7
test -f ${BACKUPROOT}/postgres-dumpall.gz.5 && mv ${BACKUPROOT}/postgres-dumpall.gz.5 ${BACKUPROOT}/postgres-dumpall.gz.6
test -f ${BACKUPROOT}/postgres-dumpall.gz.4 && mv ${BACKUPROOT}/postgres-dumpall.gz.4 ${BACKUPROOT}/postgres-dumpall.gz.5
test -f ${BACKUPROOT}/postgres-dumpall.gz.3 && mv ${BACKUPROOT}/postgres-dumpall.gz.3 ${BACKUPROOT}/postgres-dumpall.gz.4
test -f ${BACKUPROOT}/postgres-dumpall.gz.2 && mv ${BACKUPROOT}/postgres-dumpall.gz.2 ${BACKUPROOT}/postgres-dumpall.gz.3
test -f ${BACKUPROOT}/postgres-dumpall.gz.1 && mv ${BACKUPROOT}/postgres-dumpall.gz.1 ${BACKUPROOT}/postgres-dumpall.gz.2

echo "Running postgres pg_dumpall..."
cd ${BACKUPROOT}
pg_dumpall -U onlyoffice | /bin/gzip > postgres-dumpall.gz
mv ${BACKUPROOT}/postgres-dumpall.gz ${BACKUPROOT}/postgres-dumpall.gz.1
echo "...done."