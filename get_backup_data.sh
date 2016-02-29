#!/bin/bash

# Extract backup data from logfiles in a nagios friendly format
# Looking for:
#	-	Total Backup Size
#	-	Length of time for the backup
#	-	Diff in Backup Size from last run
#
#	Store output of last run in ~/.cache/backup_stats
#	-	If not run before then rturn 0


# Setenv prog has to be in the same directory the script is run from
rundir=$(dirname $0)
. ${rundir}/badger_setenv.sh $0

set -e
DEBUG=0
PRODUCTION=0
DRYRUN=""
CACHE_BASE=${HOME}/.cache/backupstats
if [ ! -d ${CACHE_BASE} ]; then
	mkdir -p ${CACHE_BASE}
fi

print_data ()
{
	printf "last_backup_start=%d\nlast_backup_end=%d\nlast_run_time=%d\nlast_backup_size=%d\nlast_backup_delta=%d\n" \
		$1 $2 $3 $4 $5 > ${CACHE_FILE_NAME}
	logger.sh INFO "last_backup_start= $1, last_backup_end=$2, last_run_time= $3, last_backup_size= $4, last_backup_delta= $5"
}

#--------------- MAIN -----------------------

#-----------------------------------------------
# Option parsing
#-----------------------------------------------

LOGFILE=$(/usr/local/bin/getlogfilename.sh "$0" )
# Parse single-letter options
while getopts df:t: opt; do
    case "$opt" in
        d) DEBUG=1
           ;;
        t) BACKUP_TYPE="$OPTARG"
           ;;
		f) BACKUP_LOGFILE="$OPTARG"
           ;;
        '?')  logger.sh FATAL "invalid option $OPTARG."
			exit 1
           ;;
    esac
done


if [ "1${BACKUP_LOGFILE}" == "1" ]; then
	logger.sh FATAL "No logfile not specified"
	exit 1
fi

if [ "1${BACKUP_TYPE}" == "1" ]; then
	logger.sh FATAL "Backup Type not specified rsync|duplicity|tarsnap"
	exit 1
fi

logger.sh INFO "Starting Backup Size calcs for ${BACKUP_LOGFILE}"

# Cache File depends on logfile following the correct convention
CACHE_FILE_NAME="${CACHE_BASE}/${BACKUP_LOGFILE}.dat"

last_backup_start=0
last_backup_end=0
last_run_time=0
last_backup_size=0
last_backup_delta=0
backup_delta=-1
if [ -f ${CACHE_FILE_NAME} ]; then
	last_backup_start=$( awk -F= '$1=="last_backup_start" {print $2; }' ${CACHE_FILE_NAME} )
	last_backup_end=$( awk -F= '$1=="last_backup_end" {print $2; }' ${CACHE_FILE_NAME} )
	last_run_time=$( awk -F= '$1=="last_run_time" {print $2; }' ${CACHE_FILE_NAME} )
	last_backup_size=$( awk -F= '$1=="last_backup_size" {print $2; }' ${CACHE_FILE_NAME} )
	last_backup_delta=$( awk -F= '$1=="last_backup_delta" {print $2; }' ${CACHE_FILE_NAME} )
fi

# For the moment assume all logfiles in /usr/local/log
# Get the latest logfile

LATEST_LOGFILE=$( ls /usr/local/log/*-${BACKUP_LOGFILE}.log | tail -1 )

if [ ! -f "${LATEST_LOGFILE}" ]; then
	logger FATAL "Couldnt find a logfile for ${LATEST_LOGFILE}"
	exit 1
fi

# Now see whether it has a different time stamp to the last end
backup_end=$( gdate -r ${LATEST_LOGFILE} +%s )

if [ "$last_backup_end" == "$backup_end" ]; then
	logger.sh INFO "No change - nothing done"
	exit 0
fi

if [ ${BACKUP_TYPE} == 'rsync' ]; then
	awk ' /DEBUG: Rsync backup -> rsync/ { start_time=$1; } \
		  /^Total file size:/				  { backup_size=$4; } \
		  END { print start_time, backup_size; }' ${LATEST_LOGFILE} > $TMPFILE1 

	start_time=$( awk '{print $1;}' $TMPFILE1 )
	backup_size=$( awk '{print $2;}' $TMPFILE1 )
	backup_start=$(/bin/date -j -f %Y%m%d:%H%M%S ${start_time} +%s)

elif [ ${BACKUP_TYPE} == 'duplicity' ]; then
	awk '/^StartTime/	{ backup_start=$2; } \
		 /^SourceFileSize/ { backup_size=$2; } \
		 END			{ printf "%d %d", backup_start, backup_size; }' ${LATEST_LOGFILE} > $TMPFILE1

	backup_start=$( awk '{print $1;}' $TMPFILE1 )
	backup_size=$( awk '{print $2;}' $TMPFILE1 )

elif [ ${BACKUP_TYPE} == 'tarsnap' ]; then
	awk ' /INFO: tarsnap backup of -> / { start_time=$1; } \
		  /^  \(unique data\)/				  { backup_size=$4; } \
		  END { print start_time, backup_size; }' ${LATEST_LOGFILE} > $TMPFILE1 

	start_time=$( awk '{print $1;}' $TMPFILE1 )
	backup_size=$( awk '{print $2;}' $TMPFILE1 )
	backup_start=$(/bin/date -j -f %Y%m%d:%H%M%S ${start_time} +%s)
else
	logger.sh FATAL "Bad Backup Type -> ${BACKUP_TYPE}"
	exit 1
fi

run_time=$(( $backup_end - $backup_start ))
if [ $last_backup_size != 0 ]; then
	backup_delta=$(( $backup_size - $last_backup_size ))
fi

print_data $backup_start $backup_end $run_time $backup_size $backup_delta

exit 0
