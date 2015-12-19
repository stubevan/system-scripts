#!/bin/bash

# Assumes file names in the format
# 20150721-MySQLBackup.log
# if older then delete

if [ -f $HOME/.bashrc ]; then
    source $HOME/.bashrc
fi

EXECUTE=0
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

	filedate=$(echo $file | awk -F- '{print $1}')
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
		echo "$file is not a log file"
	fi
done

exit 0
