#!/bin/bash

# 1) Run tarsnap backups
# 2) Pull back the specified syncstatus directory for later validation by
#    SyncStatus
# 3) Keep the archives clean


. $HOME/.bash_profile
DEBUG=0
PRODUCTION=0
EXEC_NAME=$0
HOST=$( hostname -f | tr '[:upper:]' '[:lower:]' )
TARSNAP_ATTRIBUTES="/usr/local/bin/tarsnap --keyfile ${HOME}/etc/tarsnap.key --cachedir ${HOME}/.tarsnap"
STATS_FILE=${HOME}/Dropbox/Backups/Stats/backupstats.csv
SYNCSTATUSFILE=".syncstatus"
SOURCE_DIRECTORIES="dev etc Documents Dropbox Local/DTPO"
EXCLUDES_FILE="$HOME/etc/tarsnap.excludes"
TMPLOG="/tmp/tarsnap.$$.log"
RESTORE_DIRECTORY="${HOME}/Local/SyncStatus/$HOST/tarsnap"
LOGFILE=$(getlogfilename.sh "$0")
RUNOPTS=""
RESTORE=""

# Helper methods
fatal() {
    logger.sh FATAL "$*"
    exit 1
}

usage() {
    echo "Usage: $EXEC_NAME "
    exit 1
}

#--------------- MAIN -----------------------
# Check we're not aready running
pidfile=/var/tmp/bn-tarsnap.pid

if [ -f $pidfile ]; then
    pid=`cat $pidfile`
    kill -0 $pid 2> /dev/null
    if [ $? == 0 ]; then
        # backups running elsewhere
        fatal "$0 already running - $$"
    fi
fi

printf "%d" $$ > $pidfile

#-----------------------------------------------
# Option parsing
#-----------------------------------------------

# Parse single-letter options
while getopts dpnr opt; do
    case "$opt" in
        d)    DEBUG=1
              ;;
        p)    PRODUCTION=1
              ;;
        n)    NORUN=1
			  RUNOPTS="--dry-run"
              ;;
        r)    RESTORE=1
              ;;
        '?')  fatal "invalid option $OPTARG."
              ;;
    esac
done

# if not debugging then redirect all subsequent output
if [ $PRODUCTION == 1 ]; then
    exec >> $LOGFILE 2>&1
fi

if [ "${RESTORE}" == "" ]; then
		# Run the tarsnap backup
		archive="$( date +%Y%m%d.%H%M ).${HOST}"
		logger.sh INFO "tarsnap backup of -> ${SOURCE_DIRECTORIES}"
		logger.sh INFO "Saving to archive -> $archive "

		datestamp=$( date +%Y%m%d.%H%M )

		tarsnap_backup="${TARSNAP_ATTRIBUTES} ${RUNOPTS} --checkpoint-bytes 10485760 --print-stats -v -c -f ${archive} -X ${EXCLUDES_FILE} -C ${HOME} ${SOURCE_DIRECTORIES} > ${TMPLOG} 2>&1"
		logger.sh DEBUG "Backup command -> $tarsnap_backup"
		eval $tarsnap_backup

		cat $TMPLOG; rm -f $TMPLOG
		logger.sh INFO "Backup completed"
else
		#Now try and extract the file backout so that SyncStatus can check it
		RESTORE_PATTERN="'*${SYNCSTATUSFILE}*'"
		archive=$(${TARSNAP_ATTRIBUTES} --list-archives | sort | tail -1)
		tarsnap_restore="${TARSNAP_ATTRIBUTES} ${RUNOPTS} -v -x -f ${archive} ${RESTORE_PATTERN}"


		logger.sh INFO "Restoring to -> $RESTORE_DIRECTORY"
		logger.sh DEBUG "Restore command -> $tarsnap_restore"
		if [ ! -d $RESTORE_DIRECTORY ];then
			mkdir -p $RESTORE_DIRECTORY
		fi
		(
			cd $RESTORE_DIRECTORY
			eval $tarsnap_restore

			for dir in `echo $SOURCE_DIRECTORIES | awk '{for (i=1; i<=NF; i++) print $i;}'`
			do
				if [ $(echo $dir | awk -F/ '{print NF}') -ne 1 ]; then
					target=$(basename $dir)
					if [ -d "$target" ]; then
						rm -r "$target"
						mv "$dir" "$target"
					fi
				fi
			done
		)
		logger.sh INFO "Restore completed"
fi

# Clean Up
rm $pidfile

exit 0
