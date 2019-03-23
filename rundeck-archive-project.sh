#!/usr/local/bin/bash

# Archive a rundeck project

# Setenv prog has to be in the same directory the script is run from
rundir=$(dirname $0)
. ${rundir}/badger_setenv.sh $0

# Helper methods
fatal() {
    logger.sh FATAL "$*"
    exit 1
}

usage() {
    logger.sh FATAL "Usage: $0 - -u Rundeck URL -t Token File -p Project -d Destination directory"
    exit 1
}

#-----------------------------------------------
# Option parsing
#-----------------------------------------------
set -e

DEBUG=""

# Parse single-letter options
while getopts t:p:u:d: opt; do
    case "$opt" in
        d)    destination_directory="$OPTARG"
              ;;
        p)    project="$OPTARG"
              ;;
        t)    token_file="$OPTARG"
              ;;
        u)    rundeck_url="$OPTARG"
              ;;
        '?')  usage
              ;;
    esac
done

if [ "${project}" == "" -o "${destination_directory}" == "" \
		-o "${token_file}" == "" -o "${rundeck_url}" == "" ]; then
    logger WARNING "Missing Mandatory argument"
	usage
fi

if [ ! -f "${token_file}" ]; then
    fatal "Token File file $token_file not readable"
fi

if [ ! -d "${destination_directory}" -o ! -w "${destination_directory}" ]; then
    fatal "Destination directory not accessible -> ${destination_directory}"
fi


#--------------- MAIN -----------------------

# Run the Purge
RD=/usr/local/rundeck/tools/bin/rd
if [[ ! -x "${RD}" ]]; then
	logger FATAL "Rundeck CLI tools not executable -> $RD"
fi

archive_file="${destination_directory}/$(date +%Y%m%d-%H%M%S)-RundeckArchive-${project}.tar.zip"

export RD_URL=${rundeck_url}
export RD_TOKEN=$(cat $token_file)

logger.sh INFO "Starting Archive of Rundeck Project ${project} to ${archive_file}"

$RD projects archives export --project $project -f "${archive_file}"
status=$?

if [[ $status == 0 ]]; then
	logger.sh INFO "Archive succeeded"
else
	logger.sh ERROR "Archive failed"
fi

exit $status
