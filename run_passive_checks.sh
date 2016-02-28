#!/bin/bash 
# Run passive checke define in the specified config file and then send using nrdp

. badger_setenv.sh $0

usage() {
	echo "Usage: -h hostname -t token -u url -c config-file -C check_script"
	exit 1
}

CHECK_SCRIPT=""

# Parse single-letter options
while getopts t:u:c:h:C: opt; do
    case "$opt" in
        h) LOCALHOST="$OPTARG"
           ;;
        c) CONFIG_FILE="$OPTARG"
           ;;
        t) TOKEN="$OPTARG"
           ;;
        u) TARGET_URL="$OPTARG"
           ;;
        C) CHECK_SCRIPT="$OPTARG"
           ;;
done

if [ "x${LOCALHOST}" == "x" ]; then
	logger.sh FATAL "Must specify a hostname"; exit 1
fi

if [ "x${CONFIG_FILE}" == "x" ]; then
	logger.sh FATAL "Must specify a Config File"; exit 1
fi

if [ "x${TOKEN}" == "x" ]; then
	logger.sh FATAL "Must specify a Token"; exit 1
fi

if [ "x${TARGET_URL}" == "x" ]; then
	logger.sh FATAL "Must specify a Target URL"; exit 1
fi

IFS=$'\n'

# Run the check script to see whether we go or not
if [ "x$CHECK_SCRIPT" != "x" ]; then
	if [ ! -x "${CHECK_SCRIPT}" ]; then
		logger.sh FATAL "CHECK_SCRIPT -> ${CHECK_SCRIPT} not executable"; exit 1
	fi
	logger.sh INFO "Running Connected Check"
	eval "${CHECK_SCRIPT}"
	if [ $? != 0 ]; then
		logger.sh INFO "Check Script Failed - not running checks"
		exit 0
	fi
fi

logger.sh INFO "Running Checks"

# Start with the host check
echo "${LOCALHOST}	OK	`uptime`" > ${TMPFILE1}
for sourceline in $(cat ${CONFIG_FILE} )
do
	service=$( echo $sourceline | awk -F! '{print $1}' )
	command=$( echo $sourceline | awk -F! '{print $2}' )

	# execute the command and capture the results
	eval "${command}" > $TMPFILE2
	rc=$?
	retline=$( head -1 $TMPFILE2 )

	echo "${LOCALHOST}	${service}	${rc}	${retline}" >> $TMPFILE1
done

cat ${TMPFILE1}
cat ${TMPFILE1} | send_nrdp.sh -u "${TARGET_URL}" -t "${TOKEN}"
logger.sh INFO "Checks Completed"
exit 0
