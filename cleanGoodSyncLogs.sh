#!/bin/bash
#
# Script to tidy goodsync logs into one file
# This script called from Hazel.  Given that some syncs can take a long time
# Hazel will wait before tidying
#
# Script called with one argument which is the file to be cleaned

# Formay of the input file will be like goodsync-mac-130922-1921.log

if [ ! -f $1 ]; then
	echo "Script needs a readable file passed as an argument"
	exit 1
fi

LOGFILE_DATE=`basename $1 | awk -F- '{print $3}'`

# Redirect our output for debugging purposes using the LOGFILE_DATE
# V Bad weakness as I'm assuming the script will only be run in the 21st
# century!  
TARGET_LOG="/Users/stu/Logs/20${LOGFILE_DATE}-runGoodSync.log"

exec >> $TARGET_LOG 2>&1

cat "$1" >> $TARGET_LOG

/usr/local/bin/trash "$1"