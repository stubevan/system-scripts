#!/bin/bash 

# Need directories in the format YYYYMMDD - if not then ignore them
# Second paramter is number of days to key
# if older then delete

# Set up the environment and the logging
. /usr/local/bin/badger_setenv.sh $0

EXECUTE=0
set -e

dirage() {
    d1=$(date +%s)
    d2=$(date -d "$1" +%s) > /dev/null 2>&1
    echo $(( (d1 - d2) / 86400 ))
    exit 0
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
	logger.sh FATAL "Invalid source directory -> $SOURCEDIRECTORY" >&2
	exit 1
fi

re='^[0-9]+$'
if [[ ! "$DAYSTOKEEP" =~ $re ]] ; then
	logger.sh FATAL "Days To Keep is not a number" >&2
	exit 1
fi

for dir in `ls "$SOURCEDIRECTORY" `
do
	# Check its a date format
	dir=$(basename $dir)
	re='^20[0-9]+$'
	if [[ "$dir" =~ $re ]] ; then
		# How old is it
		if [ `dirage $dir` -gt $DAYSTOKEEP ]; then
			logger.sh INFO "Deleting $SOURCEDIRECTORY/$dir"
			if [ $EXECUTE -eq 1 ]; then
				rm -rf "$SOURCEDIRECTORY/$dir"
			fi
		else
			logger.sh INFO "Keeping $SOURCEDIRECTORY/$dir"
		fi
	else
		logger.sh INFO "$dir is not an archive directory"
	fi
done

exit 0
