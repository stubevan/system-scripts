#!/bin/sh

# Run rsyncs specified for this host
# The actions are determined by the hostname


# Setenv prog has to be in the same directory the script is run from
rundir=$(dirname $0)
. ${rundir}/badger_setenv.sh $0

RSYNC_ATTRIBUTES="rsync -aiv --stats --copy-links --backup --delete -e 'ssh'"

# Helper methods
fatal() {
    logger.sh FATAL "$*"
    exit 1
}

usage() {
    logger.sh FATAL "Usage: $0 -n Name -b Backup-Dest -s source -d Destination -x Excludes File [-d] [-n]"
    exit 1
}

#-----------------------------------------------
# Option parsing
#-----------------------------------------------

CONFIG_FILE=""
EXCLUDES_FILE=""
DEBUG=""
DRYRUN=""

# Parse single-letter options
while getopts nN:b:s:D:x:d opt; do
    case "$opt" in
        N)    BACKUP_NAME="$OPTARG"
              ;;
        b)    BACKUP_DEST="$OPTARG"
              ;;
        D)    DESTINATION="$OPTARG"
              ;;
        s)    SOURCE="$OPTARG"
              ;;
        x)    EXCLUDES_FILE="$OPTARG"
              ;;
        d)    DEBUG=1
              ;;
        n)    DRYRUN="-n"
              ;;
        '?')  fatal "invalid option $OPTARG."
              ;;
    esac
done

if [ "${BACKUP_NAME}" == "" -o "${BACKUP_DEST}" == "" -o "${SOURCE}" == "" \
		-o "${DESTINATION}" == "" -o "${EXCLUDES_FILE}" == "" ]; then
    fatal "Missing Mandatory argument"
fi

if [ ! -f "${EXCLUDES_FILE}" ]; then
    fatal "Excludes File file $EXCLUDES_FILE not readable"
fi


#--------------- MAIN -----------------------

# Run the rsync backup
backupdir=${BACKUP_DEST}
source=${SOURCE}
destination=${BACKUP_DEST}

host_test=$(echo "$source" | awk -F: '{print NF}')
source_log=""
if [ "${host_test}" -eq 1 ]; then
		source=\""$source"\"
		source_log=$( echo "$source" | awk -F / '{print $(NF-1)}')
else
		source_log=$(echo "$source" | awk -F: '{ print $1; }')
		source=$(echo "$source" | awk -F: '{ printf ("%s:\"%s\"", $1, $2); }')
fi

dest_log=""
host_test=$(echo "$destination" | awk -F: '{print NF}')
if [ "${host_test}" -eq 1 ]; then
		destination=\"$( echo "$DESTINATION" )\"
else
		destination=$( eval echo "$DESTINATION" | sed "s/ /\\\ /g" | awk -F: '{ printf ("%s:\"%s\"", $1, $2); }')
fi

rsync_backup="${RSYNC_ATTRIBUTES} ${DRYRUN} --exclude-from=${EXCLUDES_FILE} --backup-dir=\"${backupdir}\" ${source} ${destination}"

# Run the backups
logger.sh DEBUG "Rsync backup -> $rsync_backup"
if [ "$DEBUG" == "" ]; then
	eval "$rsync_backup"
fi

exit 0
