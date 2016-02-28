#!/bin/bash

# 1) Run tarsnap backups
# 2) Pull back the specified syncstatus directory for later validation by
#    SyncStatus
# 3) Keep the archives clean


# Setenv prog has to be in the same directory the script is run from
rundir=$(dirname $0)
. ${rundir}/badger_setenv.sh $0

DEBUG=0
HOST=$( hostname -f | tr '[:upper:]' '[:lower:]' )

TARSNAP_ATTRIBUTES="/usr/local/bin/tarsnap --keyfile ${HOME}/etc/tarsnap.key --cachedir ${HOME}/.tarsnap"
RUNOPTS=""

SYNCSTATUSFILE=".syncstatus"
SOURCE_DIRECTORIES="home-RAID/stu/dev home-RAID/stu/etc Boxcryptor/Documents home-RAID/stu/Dropbox Boxcryptor/DTPO"

EXCLUDES_FILE="/usr/local/etc/tarsnap.excludes"
RESTORE_DIRECTORY="${HOME}/Local/SyncStatus/$HOST/tarsnap"

RESTORE=""

# Helper methods
fatal() {
    logger.sh FATAL "$*"
    exit 1
}

usage() {
    echo "Usage: $0 "
    exit 1
}

#--------------- MAIN -----------------------

#-----------------------------------------------
# Option parsing
#-----------------------------------------------

# Parse single-letter options
while getopts dnr opt; do
    case "$opt" in
        d)    DEBUG=1
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

if [ "${RESTORE}" == "" ]; then
		# Run the tarsnap backup
		archive="$( date +%Y%m%d.%H%M ).${HOST}"
		logger.sh INFO "tarsnap backup of -> ${SOURCE_DIRECTORIES}"
		logger.sh INFO "Saving to archive -> $archive "

		datestamp=$( date +%Y%m%d.%H%M )

		tarsnap_backup="${TARSNAP_ATTRIBUTES} ${RUNOPTS} --checkpoint-bytes 10485760 --print-stats -v -c -f ${archive} -X ${EXCLUDES_FILE} -C /Volumes ${SOURCE_DIRECTORIES} > ${TMPFILE1} 2>&1"
		logger.sh DEBUG "Backup command -> $tarsnap_backup"
		eval $tarsnap_backup

		cat $TMPFILE1
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

exit 0
