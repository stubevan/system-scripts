#!/bin/bash

# 1) Run duplicity backups
# 2) Pull back the specified syncstatus directory for later validation by
#    SyncStatus
# 3) Keep the archives clean

# Setenv prog has to be in the same directory the script is run from
rundir=$(dirname $0)
. ${rundir}/badger_setenv.sh $0

ulimit -n 1024

DEBUG=0

DUPLICITY_ATTRIBUTES="/usr/local/bin/duplicity "
EXCLUDES_FILE="/usr/local/etc/duplicity.excludes"

SYNCSTATUSFILE=".syncstatus"
SOURCE_DIRECTORIES=""
TARGET_HOST=$(hostname -f | awk '{print tolower($0)}' )

BACKUPS_TO_KEEP=3
DRYRUN=""
DUPTYPE=""

# Helper methods
fatal() {
    logger.sh FATAL "Duplicity $*"
    exit 1
}

usage() {
    echo "Usage: $0 "
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
while getopts F:t:dpnT:k:N:s:B: opt; do
    case "$opt" in
        B) BACKUP_BASE="$OPTARG"
           ;;
        d) DEBUG=1
           ;;
        t) TARGET="$OPTARG"
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

if [ "${BACKUP_BASE}" == "" ]; then
	BACKUP_BASE=${HOME}
fi

DESTINATION="$(echo $TARGET | sed 's,.*//\(.*\)//.*,\1,' )"
RESTORE_DIRECTORY="${HOME}/Local/SyncStatus/${TARGET_HOST}/${DESTINATION}"
duplicitylog=$(getlogfilename.sh "duplicity.${DUPLICITY_NAME}"

# get the gpg password
export PASSPHRASE=$( security find-generic-password -a stu -s GPG_KEY -w )

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
			INCLUDE_DIRS=" --include ${BACKUP_BASE}/${dir} ${INCLUDE_DIRS}"
		done
		IFS=$OLD_IFS

		full_or_inc=$(backupType $FULL_BACKUPS)
		logger.sh INFO "Backup Type -> $full_or_inc, fullbackupmonth -> $FULL_BACKUPS"

		duplicity_command="${DUPLICITY_ATTRIBUTES} --sign-key ${DUPLICITY_KEY} --name ${DUPLICITY_NAME} --encrypt-key ${DUPLICITY_KEY} ${DRYRUN} -v5 --exclude-filelist ${EXCLUDES_FILE} ${INCLUDE_DIRS} --exclude '**' $full_or_inc ${BACKUP_BASE}/ ${TARGET} >> ${duplicitylog} 2>&1"

		# Run the backups
		logger.sh DEBUG "Backup command -> $duplicity_command"
		eval $duplicity_command
		if [ $? != 0 ]; then
			fatal "Duplicity backup ${DUPLICITY_NAME} failed"
		fi

elif [ "$DUPTYPE" == "restore" ]; then

		#Now The fun bit - assume there is a sync status dir in every Source Dir
		logger.sh INFO "Starting Restores"
		OLD_IFS=$IFS
		IFS=$','
		for dir in ${SOURCE_DIRECTORIES}
		do
			logger.sh INFO "Processing -> ${dir}"
			TARGET_DIRECTORY=${RESTORE_DIRECTORY}/$(basename ${dir})/${SYNCSTATUSFILE}
			logger.sh INFO "Restoring ${dir} to -> $TARGET_DIRECTORY"

			# Do a paranoia check that its not already a regular file - have seen such weridness in the past
			if [ -f ${TARGET_DIRECTORY} ]; then
				logger.sh INFO "Cleaning regular file in target directory location"
				rm -f ${TARGET_DIRECTORY}
			fi

			if [ ! -d ${TARGET_DIRECTORY} ]; then
				logger.sh INFO "Creating -> ${TARGET_DIRECTORY}"
				mkdir -p ${TARGET_DIRECTORY}
			fi

			TMP_TARGET="/tmp/${DUPLICITY_NAME}"
			mkdir "${TMP_TARGET}"
			restore_command="${DUPLICITY_ATTRIBUTES} --sign-key ${DUPLICITY_KEY} --name ${DUPLICITY_NAME} --encrypt-key ${DUPLICITY_KEY} ${DRYRUN} -v5 --file-to-restore ${dir}/.syncstatus ${TARGET} ${TMP_TARGET}"
			logger.sh DEBUG "using -> $restore_command"
			eval "$restore_command" >> ${duplicitylog} 2>&1
			if [ $? != 0 ]; then
				rm -rf "${TMP_TARGET}"
				fatal "Duplicity restore ${DUPLICITY_NAME} failed"
			fi
			
			logger.sh INFO "Moving Status files to target"
			find ${TMP_TARGET} -name \*.st -print -exec mv {} ${TARGET_DIRECTORY} \;
			rm -rf "${TMP_TARGET}"
		done
elif [ "$DUPTYPE" == "clean" ]; then
		#run cleanup and delete old backups
		logger.sh INFO "Cleanups"
		eval ${DUPLICITY_ATTRIBUTES} --sign-key ${DUPLICITY_KEY} --name ${DUPLICITY_NAME} --encrypt-key ${DUPLICITY_KEY} ${DRYRUN} remove-all-but-n-full ${BACKUPS_TO_KEEP} --force ${TARGET} >> ${duplicitylog} 2>&1
		if [ $? != 0 ]; then
			fatal "Duplicity ${DUPLICITY_NAME} remove old backups failed"
		fi
		eval ${DUPLICITY_ATTRIBUTES} --sign-key ${DUPLICITY_KEY} --name ${DUPLICITY_NAME} --encrypt-key ${DUPLICITY_KEY} ${DRYRUN} cleanup --force ${TARGET} >> ${duplicitylog} 2>&1
		if [ $? != 0 ]; then
			fatal "Duplicity ${DUPLICITY_NAME} cleanup failed"
		fi
		logger INFO "Cleanup Finished"
else 
	fatal "Invalid backup type -> ${DUPTYPE}"
fi

logger.sh INFO "Duplicity completed"
exit 0
