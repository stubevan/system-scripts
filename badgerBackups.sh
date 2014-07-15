#!/bin/sh

# This, hopefully, should be the last incarnation of the badgerBackup process!
# The script has 3 purposes:
# 1) Run horcrux and tarsnap backups
# 2) Pull back the specified syncstatus directory for later validation by
#    SyncStatus
# 3) Keep the archives clean
# The actions are determined by the hostname


. $HOME/.bash_profile
DEBUG=0
PRODUCTION=0
EXEC_NAME=$0
HOST=$( hostname | cut -d. -f1 )
TARSNAP_ATTRIBUTES="/usr/local/bin/tarsnap --keyfile /Users/stu/etc/tarsnap.key --cachedir /Users/stu/.tarsnap"
STATS_FILE=/Users/stu/Documents/Geek/backupstats.csv
SYNCSTATUSFILE="_syncstatus"

LOGFILE="/Users/stu/Logs/`date +%Y%m%d`-badgerBackups.log"

# Helper methods
logger() {
    echo >&2 `date +%Y%m%d.%H%m%S` "-> $*"
}

fatal() {
    logger "FATAL: $*"
    exit 1
}

usage() {
	echo "Usage: $EXEC_NAME { config_file }"
	echo "	If no file system specified all entries in $CONFIG_FILE will be processed"
	echo "	If no no action and no file system specified then mount all"
	exit 1
}

getAttribute() {
    # Recover an attribute from the config file
    
    # host : horcrux : archive Name : source Directory : local Directory : comma seperated list of full backup months
    # host : tarsnap : archive Name : source Directory : local Directory : excludes
    # host : timemachine : - : source Directory : local Directory
    if [ $# != 2 ]; then
    	fatal "getAttribute called with incorrect number of parameters -> $*"
    fi
    line=$1
    action=$2
    
    case $action in
        "backup_type" )
            field=2
            ;;
        "time_machine_volume" )
            field=2
            ;;
        "archive_name" )
            field=3
            ;;
        "mount_point" )
            field=3
            ;;
        "source_directory" )
            field=4
            ;;
        "time_machine_base" )
            field=4
            ;;
        "local_directory" )
            field=5
            ;;
        "backup_base" )
            field=5
            ;;
        "excludes" )
            field=6
            ;;
        "fullbackupmonth" )
            field=6
            ;;
        *)
            fatal "Invalid action ->${action}<-"
            ;;
    esac
    
    # now get the field
    retvalue=$( echo "${line}" | awk -F: "{ print \$${field} }" )
    if [ $DEBUG != 0 ];	then
    	logger "got $retvalue for $action"
    fi
    
    if [ "$retvalue" == "" ]; then
        fatal "No data found for field $action:$field in $CONFIG_FILE"
    fi
    
    echo $retvalue
}

# For horcrux we run a full backup if its the first of the month and
# the month is specified in the config file
backupType() {
	fullbackupmonth=$1

	fullbackup="N"
	# is it the first of the month
	if [ $( date +%d ) == "01" ]; then
		month=$( date +%m )
		OLD_FS=$IFS
		IFS=,
		for check in $fullbackupmonth
		do
			check=$( printf "%02d" $check )
			if [ $check == $month ];then
				fullbackup="Y"
			fi
		done
	fi
	
	echo $fullbackup
}

recoverTimeMachine() {
    source_directory=$1
    local_directory=$2

    #Ensure the target directory is empty
    if [ -d "${local_directory}" ]; then
            rm -rf "${local_directory}"
    fi
    mkdir -p "${local_directory}"

    # Get the latest backup base
    latest_backup="`tmutil latestbackup`"
    logger "latest_backup -> ${latest_backup}"

    # Check it's accessible and if so recover the directory - it may not work!
    if [ ! "${latest_backup}" == "" ]; then
        logger "Restoring contents of ${source_directory} to ${local_directory}"
         tmutil restore "${latest_backup}/${source_directory}/${SYNCSTATUSFILE}" "${local_directory}"
    else
        logger "Latest backup ${latest_backup} not accessible"
    fi   
}

tarsnapBackup() {
    # Run the tarsnap backup
    archive=$1
    source_directory=$2
    local_directory=$3
    excludes=$4
    
    logger "Running tarsnap backup for archive -> $archive \
local_directory -> $local_directory source_directory -> $source_directory \
exludes -> $excludes"
    
    IFS=$'\n'
    
    # get the excludes list - comma seperated
    exclude_list=''
    for exclude in `echo ${excludes} | awk -F, '{ for (i=1; i<=NF; i++) print $i;}'`
    do
        exclude_list="$exclude_list --exclude $exclude"
    done

    # Run the backup first
    datestamp=$( date +%Y%m%d.%H%M )
    
    # Take care of source directories not in the home directory
    modded_source=$( echo ${source_directory} | sed "s,/,_,g" )
    tarsnap_archive=${archive}.${modded_source}
    archive_name=${datestamp}.${tarsnap_archive}
    logfile="/Users/stu/Logs/${datestamp}-tarsnap.${modded_source}.log"

    tarsnap_backup="${TARSNAP_ATTRIBUTES} --checkpoint-bytes 10485760 --print-stats -v -c -f ${archive_name} -C ${HOME} ${exclude_list} ${source_directory} > ${logfile} 2>&1"
    tarsnap_restore="${TARSNAP_ATTRIBUTES} -v -x -f ${archive_name} -C ${HOME}/${local_directory} ${source_directory}/${SYNCSTATUSFILE} >> ${logfile} 2>&1"
    
    # Run the backups
    logger "Tarsnap backup -> $tarsnap_backup"
    eval $tarsnap_backup

    # Now get the stats - well use these later - for tarsnap we only care
    # about compressed size - that's what we're paying for
    stats=$( sed -n '/Total size  Compressed size/,$p' ${logfile} | \
            awk '/^This archive/ { printf ("%d,", $3) }  \
                 /^New data/ { printf ("%d", $3)}' )
        
    printf "%s,tarsnap,%s,%s\n" ${datestamp} ${tarsnap_archive} ${stats} >> $STATS_FILE
            
    #Now try and extract the file backout so that SyncStatus can check it
    logger "Tarsnap restore -> $tarsnap_restore"
    eval $tarsnap_restore
}

horcruxBackup() {
    # Run the horcrux backup - this is much simpler!
    archive=$1
    source_directory=$2
    local_directory=$3
	fullbackup=$4

	if [ "$fullbackup" == "Y" ]; then
		backup_type="full"
	else
		backup_type="inc"
	fi
    
    # Run the backup first
    datestamp=$( date +%Y%m%d.%H%M )
    horcrux_archive="${archive}.${source_directory}"
    logger "Running horcrux backup for -> $horcrux_archive"
    logfile="/Users/stu/Logs/${datestamp}-horcrux.${horcrux_archive}.log"

    # work out the restore directory and then make sure it's not there.  Duplicity won't overwrite
    restore_directory=${HOME}/${local_directory}/${archive}/${source_directory}/${SYNCSTATUSFILE}
    if [ -d ${restore_directory} ]; then
        rm ${restore_directory}/*
        rmdir ${restore_directory}
    fi
    horcrux_backup="horcrux $backup_type $horcrux_archive >> ${logfile} 2>&1"

    horcrux_restore="horcrux -f ${SYNCSTATUSFILE} restore $horcrux_archive ${restore_directory} >> ${logfile} 2>&1"
    
    logger "Horcrux backup -> $horcrux_backup"
    eval $horcrux_backup              

    # Now get the stats - we'll use these later 
    stats=$( sed -n '/Backup Statistics/,$p' $logfile | \
        awk '/^SourceFileSize/ { printf ("%d,", $2) }  \
	     /^RawDeltaSize/ { printf ("%d\n", $2)}' )

    printf "%s,horcrux,%s,%s\n" $datestamp $horcrux_archive $stats >> $STATS_FILE

    logger "Horcrux restore -> $horcrux_restore"
    eval $horcrux_restore

	# if it's a full backup then tidy up 
	if [ "$fullbackup" == "Y" ]; then
		horcrux_clean="horcrux clean $horcrux_archive >> ${logfile} 2>&1"
		logger "Horcrux clean -> $horcrux_clean"
		eval $horcrux_clean

		horcrux_remove="horcrux remove $horcrux_archive >> ${logfile} 2>&1"
		logger "Horcrux remove -> $horcrux_remove"
		eval $horcrux_remove
	fi
}

#--------------- MAIN -----------------------
# Check we're not aready running
pidfile=/var/tmp/badgerBackups.pid

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
while getopts :c:dp opt; do
    case "$opt" in
        c)    CONFIG_FILE="$OPTARG"
              ;;
        d)    DEBUG=1
              ;;
        p)    PRODUCTION=1
              ;;
        '?')  fatal "invalid option $OPTARG."
              ;;
    esac
done

# WE have all the options - everything left is a list of backup types to process
shift $((OPTIND-1))

if [ "$CONFIG_FILE" == "" ]; then
    fatal "No Config file specified"
fi

if [ ! -f $CONFIG_FILE ]; then
    fatal "Config file $CONFIG_FILE not readable"
fi

# if not debugging then redirect all subsequent output
if [ $PRODUCTION == 1 ]; then
	exec >> $LOGFILE 2>&1
fi

# Iterate through config and get commands for this host and backup type
tarsnap_run=0
IFS=$'\n'
for line in `grep "^${HOST}:${backup_command}" $CONFIG_FILE`
do
    logger "Processing -> $line"
    backup_type=$(getAttribute "$line" "backup_type")
    archive_name=$( getAttribute "$line" "archive_name" )
    source_directory=$( getAttribute "$line" "source_directory" )
    local_directory=$( getAttribute "$line" "local_directory" )
        
    case $backup_type in
        "tarsnap")
            excludes=$( getAttribute $line "excludes" )
            tarsnapBackup $archive_name $source_directory $local_directory $excludes
	    tarsnap_run=1
            ;;
        "horcrux")
			fullmonths=$( getAttribute $line "fullbackupmonth" )
			fullbackup=$( backupType ${fullmonths} )
            horcruxBackup $archive_name $source_directory $local_directory $fullbackup
            ;;
        "time_machine")
            recoverTimeMachine $source_directory $local_directory
            ;;
        *)
            fatal "invalid operation type -> $backup_type in $line"
            ;;
    esac
done

if [ $tarsnap_run == 1 ]; then
    # Now do the prune - hardcoded parameters for now
    tarsnap_prune="/usr/local/bin/tarsnap_prune.py -t \"${TARSNAP_ATTRIBUTES}\" -H 24 -D 28 -M 6"
    logger "Tarsnap prune -> $tarsnap_prune"
    eval $tarsnap_prune
fi


# Clean Up
rm $pidfile

exit 0
