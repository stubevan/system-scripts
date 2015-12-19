#!/bin/bash 
# SyncStatus
# Either lay down an egg or return a nagios friendly output

if [ -f $HOME/.bashrc ]; then
	source $HOME/.bashrc
fi

EXECUTE=0
set -e


usage() {
	echo "Usage: syncstatus.sh -d {Directory} [ For Nagios -h {source host} -w {warning age (hours)} -c {critical age} (hours) ]"
	exit 1
}

checknumber() {
	re='^[0-9]+$'
	if [[ ! "$1" =~ $re ]] ; then
	    return 1
	fi
	return 0
}

eggfile() {
	echo "SyncStatus.$1.$(echo $2 | awk -F . '{print tolower($1)}').st"
}


# Parse single-letter options
while getopts c:d:w:h: opt; do
    case "$opt" in
        c) critical="$OPTARG"
           ;;
        d) SOURCEDIRECTORY="$OPTARG"
           ;;
        w) warning="$OPTARG"
           ;;
        h) SOURCEHOST="$OPTARG"
           ;;
    esac
done

if [ ! -d "$SOURCEDIRECTORY" ]; then
	echo "Fatal: Invalid directory -> $SOURCEDIRECTORY" >&2
	usage
fi

dir=$(basename "${SOURCEDIRECTORY}" | sed "s/ //g" )
syncdir="${SOURCEDIRECTORY}/.syncstatus"
if [ ! -d "${syncdir}" ]; then
	mkdir "${syncdir}"
fi


# which mode are we in
if [ "x${SOURCEHOST}" == "x" ]; then
	# Lay down the egg
	host=$( hostname | awk -F. '{print $1}' )
	eggfile=$(eggfile "${dir}" $host)
	date --utc +%s > "${syncdir}/${eggfile}"
else
	checknumber "${critical}" || (echo "FATAL: -c must be a number" ; usage)
	checknumber "${warning}" || (echo "FATAL: -w must be a number" ; usage)

	if [ "x${SOURCEHOST}" == "x" ]; then
		echo "Fatal: Must specify a source host"
		usage
	fi

	# Cope with localhost weirdness
	if [ "${SOURCEHOST}" == "127.0.0.1" ]; then
		SOURCEHOST=$( hostname )
	fi

	host=$( echo "${SOURCEHOST}" | awk -F. '{print $1}' )
	eggfile=$(eggfile "${dir}" $host)
	eggfile="${syncdir}/${eggfile}"
	if [ ! -f "${eggfile}" ]; then
		echo "CRITICAL: eggfile "${eggfile}" does not exist"
		exit 2
	fi

	d1=$(date --utc +%s)
	d2=$(cat "${eggfile}" | awk '{print $1}')
    delta=$(echo $(( (d1 - d2) / 3600 )))

	if [ $delta -lt ${warning} ]; then
		echo "OK: $delta hours old - created=$(date --utc -d @${d2} +%Y%m%d-%H%M%S) | delta=${delta}; ageWarn=${warning}; ageCrit=${critical}"
		exit 0
	elif [ $delta -lt ${critical} ]; then
		echo "WARNING: $delta hours old - created=$(date --utc -d @${d2} +%Y%m%d-%H%M%S) | delta=${delta}; ageWarn=${warning}; ageCrit=${critical}"
		exit 1
	elif [ $delta -ge ${critical} ]; then
		echo "CRITICAL:is $delta hours old - created=$(date --utc -d @${d2} +%Y%m%d-%H%M%S) | delta=${delta}; ageWarn=${warning}; ageCrit=${critical}"
		exit 2
	fi
fi

exit 0
