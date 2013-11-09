#!/bin/bash
# Redirect our output for debugging purposes
exec >> /Users/stu/Logs/`date +%Y%m%d`-runSyncStatus.log 2>&1

. /Users/stu/.bash_profile

sync_status.py --config ~/etc/SyncStatus.conf --log_dir ~/Logs --data_dir ~/Local/Data --mode $1 
