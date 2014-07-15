#!/bin/sh
# Redirect our output for debugging purposes
if [ $# -eq 0 ]; then
	exec >> /Users/stu/Logs/`date +%Y%m%d`-runSyncStatus.log 2>&1
	. /Users/stu/.bash_profile
fi

sync_status.py --debug --config /Users/stu/etc/SyncStatus.cfg --log_dir /Users/stu/Logs --data_file /Users/stu/Dropbox/SyncStatus/`hostname`.csv
