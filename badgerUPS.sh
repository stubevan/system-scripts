#!/bin/sh

# Called every minute on the host connected to the UPS
# Monitors for discharge events and then
# - alerts via prowl
# - when the primary battery gets down to a predefined level it will issue
#   shutdown commands to connected units - via a copied file


. $HOME/.bash_profile
DEBUG=0
PRODUCTION=0
EXEC_NAME=$0
ONBATTERY=/tmp/onbattery
HOST=$( hostname | cut -d. -f1 )

LOGFILE="/Users/stu/Logs/`date +%Y%m%d`-badgerUPS.log"

# Helper methods
logger() {
    echo >&2 `date +%Y%m%d.%H%M%S` "-> $*"
}

fatal() {
    logger "FATAL: $*"
    exit 1
}

usage() {
	echo "Usage: $EXEC_NAME -p {prowl_key} -t {threshold %} -h {comma seperated lists of hosts to shutdown}"
	exit 1
}

sendAlert() {
	event=`echo $1 | sed 's/ /%20/g'`
	description=`echo $2 | sed 's/ /%20/g'`

	alertcommand=`echo "curl \"https://api.prowlapp.com/publicapi/add?apikey=${PROWL_KEY}&application=BadgerNet%20UPS%20Alert&event=${event}&description=${description}\""`
	eval ${alertcommand}
}

issueShutdown() {
	host=$1

	logger "Sending Shutdown to ${host}"
	ssh $host "touch /tmp/UPSShutdown"
}

#--------------- MAIN -----------------------
# Check we're not aready running - this should never happen
pidfile=/var/tmp/badgerUPS.pid

if [ -f $pidfile ]; then
	pid=`cat $pidfile`
	kill -0 $pid 2> /dev/null
	if [ $? == 0 ]; then
		# UPS running elsewhere
		fatal "$0 already running - $$"
	fi
fi

printf "%d" $$ > $pidfile

#-----------------------------------------------
# Option parsing
#-----------------------------------------------

# Parse single-letter options
while getopts h:t:p:d opt; do
    case "$opt" in
        h)    HOSTS="$OPTARG"
              ;;
        t)    THRESHOLD="$OPTARG"
              ;;
        p)    PROWL_KEY="$OPTARG"
              ;;
        d)    DEBUG=1
              ;;
        '?')  fatal "invalid option $OPTARG."
              ;;
    esac
done

# if not debugging then redirect all subsequent output
if [ $DEBUG == 0 ]; then
	exec >> $LOGFILE 2>&1
fi

# See whether we're on battery or AC
UPS=`pmset -g ps`
PERCENT_CHARGED=`echo $UPS | sed 's/^.*\(...\)%;.*$/\1/' | awk '{printf ("%d", $1);}'`

if [ `echo $UPS | grep -c "discharging;"` == 0 ]; then
	# We're on AC Power - were we on battery
	logger "On AC Power -> ${PERCENT_CHARGED}"
	if [ -r $ONBATTERY ]; then
		# yes we were - alert to the fact we're back
		logger "Send Alert"
		sendAlert "AC Power Returned" "current status ${PERCENT_CHARGED}%"
		rm $ONBATTERY
	fi

	rm $pidfile
	exit 0
fi

# This is where the fun begins - we're on power 
touch $ONBATTERY

# We'll send an alert every time - don't mind - it wont be for long is AC
# doesn't come back
logger "On Battery -> ${PERCENT_CHARGED}%"
sendAlert "Running on UPS" "current status ${PERCENT_CHARGED}%"

if [ "$PERCENT_CHARGED" -lt "$THRESHOLD" ]; then
	# We're into shutdown mode
	IFS=,
	for host in $HOSTS
	do
		issueShutdown $host
	done
fi

rm $pidfile
exit 0
