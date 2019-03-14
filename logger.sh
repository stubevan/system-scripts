#!/bin/bash

# Generate an appropriate entry for a logfile
# for FATAL errors call pushover if nt running from the command line

priority=-1
message_type=""

case $1 in
	"DEBUG" | "INFO" | "WARNING" )
		message_type=$1
		shift
		;;

	"ALERT" )
		message_type=$1
		priority=0
		shift
		;;

	"FATAL" )
		message_type=$1
		priority=1
		shift
		;;

	*)
		pushover.sh -t "$(hostname) - Script Error" "Invalid log level -> $1"
		;;
esac

pid_string=""
if [ ! -z "${PARENT_PID}" ]; then
	pid_string=" (${PARENT_PID})"
fi

message_type=$(echo ${message_type} | awk '{printf("%7s", $1);}')

echo "$(date +%Y%m%d:%H%M%S)${pid_string} - ${message_type}: $*"

# Generate a pushover alert if we're not running in a tty
if [ $priority != -1  -a ! -t 0 ]; then
	pushover.sh -p ${priority} -t "$(hostname) - System Alert" "${message_type}: $*"
fi

exit 0
