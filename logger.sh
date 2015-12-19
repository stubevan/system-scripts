#!/bin/bash

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

message_type=$(echo ${message_type} | awk '{printf("%7s", $1);}')

echo "$(date +%Y%m%d:%H%M%S) - ${message_type}: $*"

if [ $priority != -1 ]; then
	pushover.sh -p ${priority} -t "$(hostname) - System Alert" "${message_type}: $*"
fi

exit 0
