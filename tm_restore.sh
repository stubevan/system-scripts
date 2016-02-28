#!/bin/bash

# Recover syncstatus files for directories archived by Time Machine


# Setenv prog has to be in the same directory the script is run from
rundir=$(dirname $0)
. ${rundir}/badger_setenv.sh $0

DEBUG=0
EXEC_NAME=$0
HOST=$( hostname | cut -d. -f1 | awk '{print tolower($0)}' | sed "s/-[0-9]$//" ) 
CONFIG_FILE="NOT SET"

# Helper methods
fatal() {
    logger.sh FATAL "$0 $*"
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
	# behaviour is different if we are on the boot partition as we have to 
	# use diskutil to get the name
    base_partition=$(df `realpath $1` | sed "s,^.*% /,/," | sed -n '2,$p')
    if [ ${base_partition} == "/" ]; then
        # we're on the boot partition
        disk=$(df $1 | awk '/^\// {print $1}' | awk -F / '{print $3}')
        volume=$(diskutil list | grep "$disk" | tail -1 | cut -c34-56 | sed "s/  *$//")
        echo "${volume}${1}"
    else
        echo $( realpath "$1" | sed 's,/Volumes/,,')
    fi
}

#--------------- MAIN -----------------------

#-----------------------------------------------
# Option parsing
#-----------------------------------------------


# Parse single-letter options
while getopts dc: opt; do
    case "$opt" in
        c)    SOURCE_FILE="$OPTARG"
              ;;
        d)    DEBUG=1
              ;;
        '?')  fatal "invalid option $OPTARG."
              ;;
    esac
done

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

	if [ ! -d "${source_dir}" ]; then
		logger.sh ALERT "Source directory does not exist -> ${source_dir}"
		continue
	fi

	restore_target=$(echo $line | awk -F, '{print $2}')

	if [ ! -d "${restore_dir}" ]; then
		logger.sh INFO "Creating restore base -> $restore_target"
		mkdir -p "$restore_target"
	fi

	if [ ! -d "${TMPFILE1}" ]; then
		mkdir ${TMPFILE1}
	fi

	restore_dir="${TMPFILE1}/.syncstatus"
	if [ -d "$restore_dir" ]; then
		rm -rf "$restore_dir"
	fi

	restore_vol="$(gettmvol $source_dir)"
	restore_source="$LATEST_BACKUP/$restore_vol/.syncstatus"
	restore_command="tmutil restore \"$restore_source\" \"$restore_dir\""

	logger.sh INFO "Executing restore -> $restore_command"
	if [ "$DEBUG" -eq 0 ]; then
		eval "$restore_command"
		if [ $? != 0 ]; then
			logger.sh ALERT "Time Machine restore failed for -> ${restore_source}"
			continu
		fi
		# Now copy the files into place - done this way to avoid the status
		# files disappearing
		logger.sh INFO "cp -Rp ${restore_dir}/ ${restore_target}"
		cp -Rp "${restore_dir}/" "${restore_target}"
		rm -rf "{$restore_dir}"
	fi
done

logger.sh INFO "Completed tm_restore"
exit 0
