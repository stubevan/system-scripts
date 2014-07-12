#/bin/sh

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
    
    # host : file : archive_name : source Directory : local Directory
    # host : horcrux : archive Name : source Directory : local Directory
    # host : tarsnap : archive Name : source Directory : local Directory : excludes
	# TMName : Time Machine Volume : Mount Point : Time Machine Base : Backup Base
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
        *)
            fatal "Invalid action ->${action}<-"
            ;;
    esac
    
    # now get the field
    retvalue=$( echo $line | awk -F: "{ print \$${field} }" )
    if [ $DEBUG != 0 ];	then
    	logger "got $retvalue for $action"
    fi
    
    if [ "$retvalue" == "" ]; then
        fatal "No data found for field $action:$field in $CONFIG_FILE"
    fi
    
    echo $retvalue
}

recoverTimeMachine() {
    archive_name=$1
    source_directory=$2
    local_directory=$3

    #create the target directory and empty it
    target_directory="${HOME}/${local_directory}/${source_directory}/.syncstatus"
    if [ ! -d "${target_directory}" ]; then
            mkdir -p "${target_directory}"
    else
            rm -f "${target_directory}"/*.st
    fi

    # Get the source directory from the config file
    # then need to add on the rest of the path to get the base to stu home

    # Get the directory in the time machine where the data resides
    time_machine_line=$( grep "^${archive_name}" $CONFIG_FILE )
    if [ "${time_machine_line}" == "" ]; then
            fatal "Couldn't find details for ${archive_name} in ${CONFIG_FILE}"
    fi

    # TMName : Time Machine Volume : Time Machine Base : Mount Point : Backup Base
    time_machine_volume=$( getAttribute "$time_machine_line" "time_machine_volume" )
    mount_point=$( getAttribute "$time_machine_line" "mount_point" )
    time_machine_base=$( getAttribute "$time_machine_line" "time_machine_base" )
    backup_base=$( getAttribute "$time_machine_line" "backup_base" )
    
    logger "timeMachineDirectory: time_machine_volume -> ${time_machine_volume}, \
mount_point -> ${mount_point}, time_machine_base -> ${time_machine_base}, \
backup_base -> ${backup_base}"

    # Check that the time machine volume is mounted - if it's not it doesn't
    # matter as we may have been called inppropriately
    df "$mount_point" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
    
        # Get the latest backup
        latest_backup=$( ls "${mount_point}/${time_machine_base}" | grep "[0-9]$" | tail -1 )
        if [ "${latest_backup}" == "" ]; then
            fatal "Cant find list of backups in ${mount_point}/${time_machine_base}"
        fi
    
        # and then set the return 
        backup_dir="${mount_point}/${time_machine_base}/${latest_backup}/${backup_base}"
    
        if [ ! -d "${backup_dir}" ]; then
            fatal "Time machine base for ${archive} -> ${backup_dir} not accessible"
        fi
    
        cp -rp "${backup_dir}/${source_directory}"/.syncstatus/* "$target_directory"
    fi
}

recoverFile() {
    # takes 3 parameters
    # archive_name
    # source file - of the form host!remote directory
    # local directory
    #
    # Source Directory can contain LATEST Embedded - this to be replaced
    # with the latest time machine entry
    # host can take a special form host_tm indicates
    
    archive_name=$1
    source_directory=$2
    local_directory=$3

    #create the target directory and empty it
    target_directory="${HOME}/${local_directory}/${source_directory}/.syncstatus"
    if [ ! -d "${target_directory}" ]; then
            mkdir -p "${target_directory}"
    else
            rm -f "${target_directory}"/*.st
    fi

    # get the base file
    time_machine_base=$( tmutil latestbackup )
    
    cp -rp "${time_machine_base}/${source_directory}"/.syncstatus/* "$target_directory"
    
    # Now get the stats - well use these later - for files computing
    # the delta is too expensive - we'll have to work that out
    stats=$( df "${time_machine_base}" | awk '{ printf ("%d\n, ", $3) }' )
    
    echo "$datestamp, file, $archive, $stats" >> $STATS_FILE
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
    tarsnap_restore="${TARSNAP_ATTRIBUTES} -v -x -f ${archive_name} -C ${HOME}/${local_directory} ${source_directory}/.syncstatus >> ${logfile} 2>&1"
    
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
    
    # Run the backup first
    datestamp=$( date +%Y%m%d.%H%M )
    horcrux_archive="${archive}.${source_directory}"
    logger "Running horcrux backup for -> $horcrux_archive"
    logfile="/Users/stu/Logs/${datestamp}-horcrux.${horcrux_archive}.log"

    # work out the restore directory and then make sure it's not there.  Duplicity won't overwrite
    restore_directory=${HOME}/${local_directory}/${archive}/${source_directory}/.syncstatus
    if [ -d ${restore_directory} ]; then
        rm ${restore_directory}/*
        rmdir ${restore_directory}
    fi
    horcrux_backup="horcrux auto $horcrux_archive >> ${logfile} 2>&1"

    # horcrux -f .syncstatus restore BadgerSet.Dropbox ~/Local/Backups/SyncStatus/MrBadgerDropbox
    horcrux_restore="horcrux -f .syncstatus restore $horcrux_archive ${restore_directory} >> ${logfile} 2>&1"
    
    logger "Horcrux backup -> $horcrux_backup"
    eval $horcrux_backup              

    # Now get the stats - we'll use these later 
    stats=$( sed -n '/Backup Statistics/,$p' $logfile | \
        awk '/^SourceFileSize/ { printf ("%d,", $2) }  \
	     /^RawDeltaSize/ { printf ("%d\n", $2)}' )

    printf "%s,horcrux,%s,%s\n" $datestamp $horcrux_archive $stats >> $STATS_FILE

    logger "Horcrux restore -> $horcrux_restore"
    eval $horcrux_restore

    # Finally cleanup
    horcrux_clean="horcrux clean $horcrux_archive >> ${logfile} 2>&1"
    logger "Horcrux clean -> $horcrux_clean"
	eval $horcrux_clean

	horcrux_remove="horcrux remove $horcrux_archive >> ${logfile} 2>&1"
	logger "Horcrux remove -> $horcrux_remove"
	eval $horcrux_remove
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
BACKUP_TYPES=$*

if [ "$CONFIG_FILE" == "" ]; then
    fatal "No Config file specified"
fi

if [ ! -f $CONFIG_FILE ]; then
    fatal "Config file $CONFIG_FILE not readable"
fi

if [ "$BACKUP_TYPES" == "" ]; then
    fatal "No backup specified"
fi

# if not debugging then redirect all subsequent output
if [ $PRODUCTION == 1 ]; then
	exec >> $LOGFILE 2>&1
fi

# Iterate through config and get commands for this host and backup type
tarsnap_run=0
for line in `grep "^${HOST}:${backup_command}" $CONFIG_FILE`
do
    logger "Processing -> $line"
    backup_type=$(getAttribute "$line" "backup_type")
    archive_name=$( getAttribute "$line" "archive_name" )
    source_directory=$( getAttribute "$line" "source_directory" )
    local_directory=$( getAttribute "$line" "local_directory" )
        
    case $backup_type in
        "file")
            recoverFile $archive_name $source_directory $local_directory
            ;;
        "tarsnap")
            excludes=$( getAttribute $line "excludes" )
            tarsnapBackup $archive_name $source_directory $local_directory $excludes
			tarsnap_run=1
            ;;
        "horcrux")
            horcruxBackup $archive_name $source_directory $local_directory         
            ;;
        "time_machine")
            recoverTimeMachine $archive_name $source_directory $local_directory
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
