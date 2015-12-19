#!/bin/bash

# Cleanup script specific to the web server
# Assumes file names in the format
# Backup-20150521-020001-Delta.tar.gz or  MySQLBackup-20150325.sql.gz
# if older then delete

EXECUTE=0
set -e

fileage() {
    d1=$(date +%s)
    d2=$(date -d "$1" +%s)
    echo $(( (d1 - d2) / 86400 ))
}


# Parse single-letter options
while getopts ed:a: opt; do
    case "$opt" in
        e) EXECUTE=1
           ;;
        d) SOURCEDIRECTORY="$OPTARG"
           ;;
        a) DAYSTOKEEP="$OPTARG"
           ;;
    esac
done

if [ ! -d "$SOURCEDIRECTORY" ]; then
	echo "Fatal: Invalid source directory -> $SOURCEDIRECTORY" >&2
	exit 1
fi

re='^[0-9]+$'
if [[ ! "$DAYSTOKEEP" =~ $re ]] ; then
	echo "Fatal: Days To Keep is not a number" >&2
	exit 1
fi

for file in `ls "$SOURCEDIRECTORY" `
do
	# Check its a valid file

	filedate=$(echo $file | awk -F- '{print substr($2, 1, 8);}')
	date -d "$filedate" > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		# How old is it
		if [ `fileage $filedate` -gt $DAYSTOKEEP ]; then
			echo "Deleting $SOURCEDIRECTORY/$file"
			if [ $EXECUTE -eq 1 ]; then
				rm -f "$SOURCEDIRECTORY/$file"
			fi
		else
			echo "Keeping $SOURCEDIRECTORY/$file"
		fi
	else
		echo "$file is not a backup file"
	fi
done
