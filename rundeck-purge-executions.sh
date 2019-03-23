#!/usr/local/bin/bash

# Purge old rundeck executions


# Setenv prog has to be in the same directory the script is run from
rundir=$(dirname $0)
. ${rundir}/badger_setenv.sh $0

# Helper methods
fatal() {
    logger.sh FATAL "$*"
    exit 1
}

usage() {
    logger.sh FATAL "Usage: $0 - -u Rundeck URL -t Token File -p Project -s status [succeeded|failed] -a age [e.g. 2w 3m]"
    exit 1
}

#-----------------------------------------------
# Option parsing
#-----------------------------------------------
set -e

DEBUG=""

# Parse single-letter options
while getopts t:p:s:a:u: opt; do
    case "$opt" in
        a)    age="$OPTARG"
              ;;
        p)    project="$OPTARG"
              ;;
        s)    status="$OPTARG"
              ;;
        t)    token_file="$OPTARG"
              ;;
        u)    rundeck_url="$OPTARG"
              ;;
        '?')  usage
              ;;
    esac
done

if [ "${age}" == "" -o "${project}" == "" -o "${status}" == "" \
		-o "${token_file}" == "" -o "${rundeck_url}" == "" ]; then
    logger WARNING "Missing Mandatory argument"
	usage
fi

if [ ! -f "${token_file}" ]; then
    fatal "Token File file $token_file not readable"
fi


#--------------- MAIN -----------------------

# Run the Purge
RD=/usr/local/rundeck/tools/bin/rd
if [[ ! -x "${RD}" ]]; then
	logger FATAL "Rundeck CLI tools not executable -> $RD"
fi

export RD_URL=${rundeck_url}
export RD_TOKEN=$(cat $token_file)

logger.sh INFO "Deleting $status executions older than $age"

$RD executions deletebulk --project $project --status $status --older "${age}" --confirm --max 10000
status=$?

exit $status
