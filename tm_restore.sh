#!/bin/bash

# Recover syncstatus files for directories archived by Time Machine


. "$HOME/.bash_profile"
DEBUG=0
PRODUCTION=0
EXEC_NAME=$0
HOST=$( hostname | cut -d. -f1 | awk '{print tolower($0)}' | sed "s/-[0-9]$//" ) 
CONFIG_FILE="NOT SET"

# shellcheck disable=SC2086
LOGFILE=$(getlogfilename.sh "$0")

# Helper methods
fatal() {
    logger.sh FATAL "$EXEC_NAME $*"
	kill -TERM "$TOP_PID"
    exit 1
}

usage() {
    echo "Usage: $EXEC_NAME -c config_file -d -p "
    echo "	If no file system specified all entries in $CONFIG_FILE will be processed"
    echo "	If no no action and no file system specified then mount all"
    exit 1
}

gettmvol () {
	# Get the correct path of the directory being restored
	cd $1
	if [ "`pwd -P`" != "`pwd`" ]; then
		x=$(cd $1; pwd -P | sed "s,/Volumes/,,")
		echo "$x"
	else
		# we're on the boot partition
		disk=$(df . | awk '/^\// {print $1}' | awk -F / '{print $3}')
		volume=$(diskutil list | grep "$disk" | tail -1 | cut -c34-56 | sed "s/  *$//")
		echo "$volume/$1"
	fi
}

#--------------- MAIN -----------------------
# Check we're not aready running
pidfile="/var/tmp/$(basename $0).pid"

if [ -f "$pidfile" ]; then
    kill -0 "$(cat $pidfile)" 2> /dev/null
    if [ $? = 0 ]; then
        # backups running elsewhere
        logger.sh INFO "$0 already running - $$"
		exit 0
    fi
fi

printf "%d" $$ > "$pidfile"
TOP_PID=$$

#-----------------------------------------------
# Option parsing
#-----------------------------------------------


# Parse single-letter options
while getopts dpc: opt; do
    case "$opt" in
        c)    SOURCE_FILE="$OPTARG"
              ;;
        d)    DEBUG=1
              ;;
        p)    PRODUCTION=1
              ;;
        '?')  fatal "invalid option $OPTARG."
              ;;
    esac
done

# if not debugging then redirect all subsequent output
if [ ${PRODUCTION} -eq  1 ]; then
    exec >> "$LOGFILE" 2>&1
fi

if [ ! -f "${SOURCE_FILE}" ]; then
	fatal "Config file not readable -> ${SOURCE_FILE}"
fi

# Dont try anything if the Time Machine Drive not mounted
tm_check=$(df | grep -c 'Time Machine')
if [ $tm_check == '0' ]; then
	logger.sh INFO "Time machine Not Available - Quitting"
	exit 0
fi

logger.sh INFO "Starting tm_restore"
# Get list of time machine backups on this host and process them
LATEST_BACKUP="$(tmutil latestbackup)"
logger.sh INFO "Latest Backup is -> ${LATEST_BACKUP}"

cat $SOURCE_FILE | while read line
do
	logger.sh INFO "processing -> $line"
	source_dir=$(echo $line | awk -F, '{print $1}')
	restore_target=$(echo $line | awk -F, '{print $2}')

	if [ ! -d "$restore_dir" ]; then
		logger.sh INFO "Creating restore base -> $restore_target"
		mkdir -p "$restore_target"
	fi

	if [ ! -d "/tmp/$$" ]; then
		mkdir /tmp/$$
	fi

	restore_dir="/tmp/$$/.syncstatus"
	if [ -d "$restore_dir" ]; then
		rm -r "$restore_dir"
	fi

	restore_vol="$(gettmvol $source_dir)"
	restore_source="$LATEST_BACKUP/$restore_vol/.syncstatus"
	restore_command="tmutil restore \"$restore_source\" \"$restore_dir\""
	logger.sh INFO "Executing restore -> $restore_command"
	if [ "$DEBUG" -eq 0 ]; then
		eval "$restore_command"
		if [ $? != 0 ]; then
			fatal "Time Machine restore failed"
		fi

		# Now copy the files into place - done this way to avoid the status
		# files disappearing
		echo cp -Rp "${restore_dir}/" "${restore_target}"
		cp -Rp "${restore_dir}/" "${restore_target}"
		rm -rf "{$restore_dir}"
	fi
done

# Clean Up
rm "$pidfile"

logger.sh INFO "Completed tm_restore"
exit 0
