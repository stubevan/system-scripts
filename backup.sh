#!/bin/sh

BACKUP_DATE=$(date +%Y%m%d)
BACKUPS="/backups"
TRACKFILE=/backups/.latestbackup
EXCLUDES="--exclude=/backups --exclude=/proc --exclude=/lost+found --exclude=/sys --exclude=/mnt --exclude=/media --exclude=/dev"

LOGFILE="/home/headbadger/logs/${BACKUP_DATE}-Backup.log"

exec >> $LOGFILE 2>&1

echo "$(date) - Starting"

# If trackfile doesnt exist or its the first day of the month then do a full backup
dom=$(date +%d)
backup_target="${BACKUPS}/Backup-${BACKUP_DATE}"
full_backup_target="${backup_target}-Full.tar.gz"

# run a full backup is not done before or its the first day of the month
if [ ! -r ${full_backup_target} ] && [ "$dom" -eq "01" -o ! -r $TRACKFILE ]; then
	echo "Full Backup"
	touch $TRACKFILE
	/bin/tar -cvzpf ${full_backup_target} ${EXCLUDES} /
else
	echo "Delta Backup since $(stat --format=%y $TRACKFILE)"
	if [ ! -r $TRACKFILE ]; then
		echo "No Trackfile - FATAL"
		exit 1
	fi

	TARGET="${backup_target}-$(date +%H%M%S)-Delta.tar.gz"
	/bin/tar -cvzpf ${TARGET} --newer=${TRACKFILE} ${EXCLUDES} / 2>&1 | grep -v 'file is unchanged; not dumped' | grep -v "/$"
	touch $TRACKFILE
fi

echo "$(date) - Completed"
