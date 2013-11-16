#/bin/sh

# This, hopefully, should be the last incarnation of the badgerBackup process!
# The script has 3 purposes:
# 1) Run horcrux and tarsnap backups
# 2) Pull back the specified syncstatus directory for later validation by
#    SyncStatus
# 3) Keep the archives clean
# The actions are determined by the hostname

DEBUG=0

logger() {
    echo >&2 `date +%Y%m%d.%H%m%S` "-> $*"
}

fatal() {
    logger "FATAL: $*"
    exit 1
}

log="/Users/stu/Logs/`date +%Y%m%d`-badgerBackups.log"

# Check we're not aready running
pidfile=/var/tmp/badgerBackups.pid

if [ -f $pidfile ]; then
	pid=`cat $pidfile`
	kill -0 $pid
	if [ $? == 0 ]; then
		# backups running elsewhere
		fatal "$0 already running - $$"
	fi
fi

printf "%d" $$ > $pidfile

if [ $DEBUG == 0 ]; then
	exec >> $log 2>&1
fi

. $HOME/.bash_profile
EXEC_NAME=$0
HOST=$( hostname | cut -d. -f1 )
TARSNAP_ATTRIBUTES="/usr/local/bin/tarsnap --keyfile /Users/stu/etc/tarsnap.key --cachedir /Users/stu/.tarsnap"
STATS_FILE=/Users/stu/Documents/Geek/backupstats.csv

usage() {
	echo "Usage: $EXEC_NAME { config_file }"
	echo "	If no file system specified all entries in $CONFIG_FILE will be processed"
	echo "	If no no action and no file system specified then mount all"
	exit 1
}

getAttribute() {
    # Recover an attribute from the config file
    
    # host : file : archive_name source Directory : local Directory
    # host : horcrux : archive Name : source Directory : local Directory
    # host : tarsnap : archive Name : source Directory : local Directory : excludes
    if [ $# != 2 ]; then
    	fatal "getAttribute called with incorrect number of parameters -> $*"
    fi
    line=$1
    action=$2
    
    if [ "$action" == "backup_type" ]; then
        field=2
    else
        backup_type=$( getAttribute $line "backup_type" )

		if [ $DEBUG != 0 ]; then
			logger "backup_type -> $backup_type for $action"
		fi

        case $action in
            "archive_name" )
                field=3
                ;;
            "source_directory" )
                 field=4
                ;;
            "local_directory" )
                field=5
                ;;
            "excludes" )
                field=6
                ;;
            *)
                fatal "Invalid action ->${action}<-"
		;;
        esac
    fi
    
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
    
    cp -rp $source_directory $local_directory
    
    # Now get the stats - well use these later - for files computing
    # the delta is too expensive - we'll have to work that out
    stats=$( df $source_directory | awk '{ printf ("%d\n, ", $3)' )
    
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
	tarsnap_archive=${archive}.${source_directory}
    archive_name=${datestamp}.${tarsnap_archive}
    logfile="/Users/stu/Logs/${datestamp}-tarsnap.${source_directory}.log"

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

    # Now do the prune - hardcoded parameters for now
	tarsnap_prune="/usr/local/bin/tarsnap_prune.py -t \"${TARSNAP_ATTRIBUTES}\" -H 24 -D 28 -M 6 -A ${tarsnap_archive}"
	logger "Tarsnap prune -> $tarsnap_prune"
	eval $tarsnap_prune
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
	horcrux_clean="horcrux clean $horcrux_archive"
	logger "Horcrux clean -> $horcrux_clean"
}

if [ $# -eq 0 ]; then
    CONFIG_FILE=$HOME/etc/backups.conf
elif [ $# -eq 1 ]; then
    CONFIG_FILE=$1
else
    usage
fi

if [ ! -f $CONFIG_FILE ]; then
	fatal "FATAL: Config file $CONFIG_FILE not readable"
fi

# Used to store reference points for tarsnap backups
if [ ! -d $TARSNAP_TIME_POINTS ]; then
	mkdir -p $TARSNAP_TIME_POINTS
fi

# Iterate through config and get commands for this host
for line in `grep "^${HOST}:" $CONFIG_FILE`
do
    logger "Processing -> $line"
    backup_type=$(getAttribute $line "backup_type")
    archive_name=$( getAttribute $line "archive_name" )
    source_directory=$( getAttribute $line "source_directory" )
    local_directory=$( getAttribute $line "local_directory" )
    
    case $backup_type in
        "File")
            recoverFile $archive_name $source_directory $local_directory
            ;;
        "tarsnap")
            excludes=$( getAttribute $line "excludes" )
            tarsnapBackup $archive_name $source_directory  $local_directory $excludes
            ;;
        "horcrux")
            horcruxBackup $archive_name $source_directory $local_directory         
            ;;
        *)
            fatal "invalid operation type -> $backup_type"
            ;;
    esac
done

rm $pidfile
