#!/bin/bash

set -eou pipefail

backupdir=/opt/backups
localretentiondays=15

find "${backupdir}/postgres" -mtime +${localretentiondays} -exec rm {} \;
find "${backupdir}/redis" -mtime +${localretentiondays} -exec rm {} \;

# Only store one dump per day for files older then yesterday
while IFS= read -r -d '' file
do
  oclock=$(echo "$file" | cut -d . -f 2)
  if [ "${oclock}x" != "00x" ]; then
    rm "$file"
  fi

done < <(find /opt/backups/ -type f -mtime +1 -print0)
