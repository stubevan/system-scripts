#!/bin/bash

# Extract any errors from the latest chrono sync log

. badger_setenv.sh $0

DEBUG=0
PRODUCTION=0
EXEC_NAME=$0
LOGDIR=/usr/local/log
HOST=$( hostname | cut -d. -f1 | awk '{print tolower($0)}' | sed "s/-[0-9]$//" ) 
CONFIG_FILE="NOT SET"

# Helper methods
fatal() {
    logger.sh FATAL "$EXEC_NAME $*"
	kill -TERM "$TOP_PID"
    exit 1
}

usage() {
    echo "Usage: $EXEC_NAME {-l logfile} -d"
    echo "	will use latest chrono sync file in /usr/local/log unless file specified"
	echo "  will redirect output to logfile unless -d set"
    exit 1
}

#-----------------------------------------------
# Option parsing
#-----------------------------------------------

IPFILE=""
# Parse single-letter options
while getopts dl: opt; do
    case "$opt" in
        l)    IPFILE="$OPTARG"
              ;;
        d)    DEBUG=1
              ;;
        '?')  fatal "invalid option $OPTARG."
              ;;
    esac
done

if [ "x${IPFILE}" == "x" ]; then
	IPFILE=$(ls ${LOGDIR}/*-ChronoSync-* | tail -1 )
fi

if [ ! -f "${IPFILE}" ]; then
	fatal "Input file not readable -> ${IPFILE}"
fi

logger.sh INFO "Processing ChronoSync Logfile -> ${IPFILE}"

# Time for a bit of awkage
message=$( awk '\
/\*\*.*Error:/	{ startcollecting=1; } \
				{ if ( startcollecting > 1 ) { print $0 }  \
				  if ( startcollecting > 2 ) { startcollecting = 0; } \
				  if ( startcollecting > 0 ) { startcollecting++; } \
				}' $IPFILE | \
	sed 's/^.*      \([^ ].*$\)/\1/' | \
	awk '{if (x==0) { x=1; ip=$0; } else { x=0; printf ("%s - %s\n", ip, $0); }}' \
)

if [ ! "x${message}" == "x" ]; then
	# Messages to deliver - lets see of it was fatal
	priority=0
	title=$( basename "$IPFILE" | sed 's/^.*ChronoSync-\(.*\).log$/\1/' )
	fatal=$(grep -c '\* Aborted \*' $IPFILE) 
	if [ $fatal > 0 ]; then
		priority=1
	fi

	logger.sh INFO "Sending message -> ${message}"

	pushover.sh -p ${priority} -t "${title}" "${message}"
else
	logger.sh INFO "No Errors"
fi

				
logger.sh INFO "Completed processing logfile"
exit 0
