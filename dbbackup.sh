#!/bin/sh


BACKUP_DATE=$(date +%Y%m%d)
BACKUPS="/backups"
PASSWORD="(jxBU2zsRP_Q%N7pat5A"

LOGFILE="/home/headbadger/logs/${BACKUP_DATE}-MySQLBackup.log"

exec >> $LOGFILE 2>&1

echo "$(date) - Starting"

backup_target="${BACKUPS}/MySQLBackup-${BACKUP_DATE}.sql.gz"
/usr/bin/mysqldump --all-databases --user=root --password="${PASSWORD}" | gzip -9 > "${backup_target}"

echo "$(date) - Completed"
