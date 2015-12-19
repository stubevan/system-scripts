#!/bin/sh

# Run rsyncs specified for this host
# The actions are determined by the hostname


. "$HOME/.bash_profile"
PRODUCTION=0
EXEC_NAME=$0
HOST=$( hostname | cut -d. -f1 | awk '{print tolower($0);}' )
RSYNC_ATTRIBUTES="rsync -aiv --stats --backup --delete -e 'ssh'"
STATS_FILE=${HOME}/Dropbox/Backups/backupstats.csv
TOP_PID=""

# Helper methods
fatal() {
    logger.sh FATAL "$EXEC_NAME - $*"
	if [ ! "$TOP_PID" == "" ]; then
		kill -TERM "$TOP_PID"
	fi
    exit 1
}

usage() {
    logger.sh FATAL "Usage: $EXEC_NAME -n Name -b Backup-Dest -s source -d Destination -x Excludes File [-d] [-n]"
    exit 1
}

#-----------------------------------------------
# Option parsing
#-----------------------------------------------

CONFIG_FILE=""
EXCLUDES_FILE=""
DEBUG=""
DRYRUN=""
PRODUCTION=""

# Parse single-letter options
while getopts nN:b:s:D:x:dp opt; do
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
        p)    PRODUCTION=1
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


LOGFILE=$(getlogfilename.sh $0 | sed "s/.log$/.${BACKUP_NAME}.log/")

# if not debugging then redirect all subsequent output
if [ "$PRODUCTION" = 1 ]; then
    exec >> "$LOGFILE" 2>&1
fi

#--------------- MAIN -----------------------
# Check we're not aready running
pidfile=/var/tmp/rsync.${BACKUP_NAME}.pid

if [ -f "$pidfile" ]; then
    kill -0 "$(cat $pidfile)" 2> /dev/null
    if [ $? -eq 0 ]; then
        # backups running elsewhere
        fatal "$0 already running - $$"
    fi
fi

printf "%d" $$ > $pidfile
TOP_PID=$$

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

# Now get the stats - well use these later - for tarsnap we only care
# about compressed size - that's what we're paying for
#stats=$( sed -n '/Total size  Compressed size/,$p' ${logfile} | \
#        awk '/^This archive/ { printf ("%d,", $3) }  \
#             /^New data/ { printf ("%d", $3)}' )

#printf "%s,rsync,%s,%s\n" ${datestamp} ${tarsnap_archive} ${stats} >> $STATS_FILE
	

# Clean Up
rm $pidfile

exit 0
