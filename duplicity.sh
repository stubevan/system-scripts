#!/bin/bash

# 1) Run duplicity backups
# 2) Pull back the specified syncstatus directory for later validation by
#    SyncStatus
# 3) Keep the archives clean


. $HOME/.bash_profile

ulimit -n 1024
DEBUG=0
PRODUCTION=0
EXEC_NAME=$0
HOST=$( hostname | cut -d. -f1 )
DUPLICITY_ATTRIBUTES="/usr/local/bin/duplicity "
STATS_FILE="${HOME}/Dropbox/Backups/backupstats.csv"
SYNCSTATUSFILE=".syncstatus"
SOURCE_DIRECTORIES=""
TARGET_HOST=$(hostname -f | awk '{print tolower($0)}' )
EXCLUDES_FILE="/usr/local/etc/duplicity.excludes"
TMPLOG="/tmp/duplicity.$$.log"
BACKUPS_TO_KEEP=3
DRYRUN=""
DUPTYPE=""

# Helper methods
fatal() {
    logger.sh FATAL "Duplicity $*"
    exit 1
}

usage() {
    echo "Usage: $EXEC_NAME "
    exit 1
}

# For duplicity we run a full backup if its the first of the month and
# the month is specified in the config file
backupType() {
    fullbackupmonth=$1

    fullbackup="incremental"
    # is it the first of the month
    if [ $( date +%02d ) == "01" ]; then
        month=$( date +%m )
        OLD_FS=$IFS
        IFS=,
        for check in $fullbackupmonth
        do
            check=$( printf "%02d" $check )
            if [ $check == $month ];then
                fullbackup="full"
            fi
        done
    fi

    echo $fullbackup
}

#--------------- MAIN -----------------------

#-----------------------------------------------
# Option parsing
#-----------------------------------------------

# Parse single-letter options
while getopts F:t:dpnT:k:N:s: opt; do
    case "$opt" in
        d) DEBUG=1
           ;;
        t) TARGET="$OPTARG"
           ;;
        p) PRODUCTION=1
    	   exec >> $LOGFILE 2>&1
		   ;;
		F) FULL_BACKUPS="$OPTARG"
           ;;
		n) DRYRUN="--dry-run"
           ;;
		T) DUPTYPE="$OPTARG"
           ;;
		k) DUPLICITY_KEY="$OPTARG"
           ;;
		N) DUPLICITY_NAME="$OPTARG"
		   LOGFILE=$(/usr/local/bin/getlogfilename.sh "$0" | sed "s/.log$/.${DUPLICITY_NAME}.log/" )
           ;;
		s) SOURCE_DIRECTORIES="$OPTARG"
           ;;
        '?')  fatal "invalid option $OPTARG."
           ;;
    esac
done

if [ "1${TARGET}" == "1" ]; then
	fatal "Destination not specified"
fi

if [ "1${DUPLICITY_KEY}" == "1" ]; then
	fatal "Encrypt/Sign key not specified"
fi

if [ "1${DUPLICITY_NAME}" == "1" ]; then
	fatal "Backup Name key not specified"
fi

if [ "1${SOURCE_DIRECTORIES}" == "1" ]; then
	fatal "Source Directory List not specified"
fi

if [ "${DUPTYPE}" == "backup" -a "${FULL_BACKUPS}" == "" ]; then
	fatal "Must specifiy when full backups done"
fi

DESTINATION="$(echo $TARGET | sed 's,.*//\(.*\)//.*,\1,' )"
RESTORE_DIRECTORY="${HOME}/Local/SyncStatus/${TARGET_HOST}/${DESTINATION}"

# Check we're not aready running
pidfile=/var/tmp/bn-duplicity.${DUPLICITY_NAME}.pid

if [ -f $pidfile ]; then
    pid=`cat $pidfile`
    kill -0 $pid 2> /dev/null
    if [ $? == 0 ]; then
        # backups running elsewhere
        fatal "$0 ${DUPLICITY_NAME} already running - $$"
    fi
fi

# get the gpg password
export PASSPHRASE=$( security find-generic-password -a stu -s GPG_KEY -w )

printf "%d" $$ > $pidfile
if [ "$DUPTYPE" == "backup" ]; then
		# Run the tarsnap backup
		archive="$( date +%Y%m%d.%H%M ).MrBadger"
		logger.sh INFO "Duplicity backup of -> ${SOURCE_DIRECTORIES}"
		logger.sh INFO "Saving to destination -> $DESTINATION "

		# Run the backup first
		datestamp=$( date +%Y%m%d.%H%M )

		# Construct the include string
		INCLUDE_DIRS=""
		OLD_IFS=$IFS
		IFS=$','
		for dir in ${SOURCE_DIRECTORIES}
		do
			INCLUDE_DIRS=" --include ${HOME}/${dir} ${INCLUDE_DIRS}"
		done
		IFS=$OLD_IFS

		duplicity_command="${DUPLICITY_ATTRIBUTES} --sign-key ${DUPLICITY_KEY} --name ${DUPLICITY_NAME} --encrypt-key ${DUPLICITY_KEY} ${DRYRUN} -v5 --exclude-filelist ${EXCLUDES_FILE} ${INCLUDE_DIRS} --exclude '**' $(backupType $FULL_BACKUPS) ${HOME}/ ${TARGET} > ${TMPLOG} 2>&1"

		# Run the backups
		logger.sh DEBUG "Backup command -> $duplicity_command"
		eval $duplicity_command
		if [ $? != 0 ]; then
		    cat $TMPLOG; rm $TMPLOG
			fatal "Duplicity backup ${DUPLICITY_NAME} failed"
		fi
		cat $TMPLOG; rm $TMPLOG

elif [ "$DUPTYPE" == "restore" ]; then

		#Now The fun bit - assume there is a sync status dir in every Source Dir
		logger.sh INFO "Starting Restores"
		OLD_IFS=$IFS
		IFS=$','
		for dir in ${SOURCE_DIRECTORIES}
		do
			#dir=$(basename "$dir")
			TARGET_DIRECTORY=${RESTORE_DIRECTORY}/${dir}
			if [ ! -d ${TARGET_DIRECTORY} ]; then
				logger.sh INFO "Creating -> ${TARGET_DIRECTORY}"
				mkdir -p ${TARGET_DIRECTORY}
			fi

			TARGET_DIRECTORY=${RESTORE_DIRECTORY}/${dir}/${SYNCSTATUSFILE}
			logger.sh INFO "Restoring ${dir} to -> $TARGET_DIRECTORY"

			TMP_TARGET="/tmp/${DUPLICITY_NAME}"
			mkdir "${TMP_TARGET}"
			restore_command="${DUPLICITY_ATTRIBUTES} --sign-key ${DUPLICITY_KEY} --name ${DUPLICITY_NAME} --encrypt-key ${DUPLICITY_KEY} ${DRYRUN} -v5 --file-to-restore ${dir}/.syncstatus ${TARGET} ${TMP_TARGET}"
			logger.sh DEBUG "using -> $restore_command"
			eval "$restore_command" > ${TMPLOG} 2>&1
			if [ $? != 0 ]; then
				rm -rf "${TMP_TARGET}"
				cat ${TMPLOG} | egrep -v '^Added incremental |^Ignoring incremental|^Import of|^Deleting |^Processed'
				rm "${TMPLOG}"
				fatal "Duplicity restore ${DUPLICITY_NAME} failed"
			fi
			
			logger.sh INFO "Moving Status files to target"
			find ${TMP_TARGET} -name \*.st -print -exec mv {} ${TARGET_DIRECTORY} \;
			rm -rf "${TMP_TARGET}"

			#Clean up the duplicity out put 
			cat ${TMPLOG} | egrep -v '^Added incremental |^Ignoring incremental|^Import of|^Deleting |^Processed'; rm $TMPLOG
		done
elif [ "$DUPTYPE" == "clean" ]; then
		#run cleanup and delete old backups
		logger INFO "Cleaning up"
		logger.sh INFO "Cleanups"
		eval ${DUPLICITY_ATTRIBUTES} --sign-key ${DUPLICITY_KEY} --name ${DUPLICITY_NAME} --encrypt-key ${DUPLICITY_KEY} ${DRYRUN} remove-all-but-n-full ${BACKUPS_TO_KEEP} --force ${TARGET}
		if [ $? != 0 ]; then
			fatal "Duplicity ${DUPLICITY_NAME} remove old backups failed"
		fi
		eval ${DUPLICITY_ATTRIBUTES} --sign-key ${DUPLICITY_KEY} --name ${DUPLICITY_NAME} --encrypt-key ${DUPLICITY_KEY} ${DRYRUN} cleanup --force ${TARGET}
		if [ $? != 0 ]; then
			fatal "Duplicity ${DUPLICITY_NAME} cleanup failed"
		fi
		logger INFO "Cleanup Finished"
else 
	fatal "Invalid backup type -> ${DUPTYPE}"
fi

rm $pidfile
rm $TMPLOG

logger.sh INFO "Duplicity completed"
exit 0
