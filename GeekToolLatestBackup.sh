#!/bin/sh

exec 3>&1
exec >> /Users/stu/Logs/`date +%Y%m%d`-GeekToolLatestBackup.log 2>&1

echo "Started - `date`"

# Get the latest timemachine backup in a form suitable for geektool
# Store the last successful result in case we're offline

LASTBACKUPFILE=/Users/stu/Local/Data/LatestBackup.txt

if [ ! -r $LASTBACKUPFILE ]; then
	echo "Not Available" > $LASTBACKUPFILE
fi

latest_backup=`/usr/bin/tmutil latestbackup`
if [ $? == 0 ]; then
	# We managed to get a status
	backup_text=`basename "$latest_backup" | cut -c 1-15`
	echo $backup_text > $LASTBACKUPFILE
	rc=0
else
	backup_text="`cat $LASTBACKUPFILE` (OL)"
	rc=1
fi

echo "Finished -> `date`"

echo "Latest Time Machine Backup ${backup_text}" >&3
exit $rc
