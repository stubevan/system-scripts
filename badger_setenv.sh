#!/usr/local/bin/bash

# Script which will be called by all BadgerNet scripts to set up the environment
# and also to ensure that logging is appropriately setup

ME=badger-setenv.sh
PATH=/usr/local/bin:/usr/local/sbin:$PATH
export PARENT_PID=$$

# Check that key executables are there
which logger.sh > /dev/null 2>&1
if [ $? != 0 ]; then
	# We're a bit stuck so can only go to stderr
	echo "FATAL - Can't find logger.sh" >&2
	exit 1
fi

which getlogfilename.sh > /dev/null 2>&1
if [ $? != 0 ]; then
	# We're a bit stuck so can only go to stderr
	logger.sh FATAL "getlogfilename.sh not in PATH -> $PATH"
	exit 1
fi

# Make sure that the executable name has been passed in 

if [ $# -ne 1 ]; then
	logger.sh FATAL "$ME needs to the pathname of the parent executable as a parameter"
	exit 1
fi

# See if we're running as a daemon - in which case redirect the output
if [ ! -t 0 ]; then
    exec >> $(getlogfilename.sh $1) 2>&1
fi

# Set up tmpfiles and associated removal on exit
for i in 1 2 3 4
do
	export TMPFILE${i}=/tmp/$$-${i}
done

# Check we're not aready running
pidfile=/tmp/pidfile.$(basename $1)

trap "rm -rf /tmp/$$-[1-4] $pidfile"  exit 1 2 15;

if [ -f "$pidfile" ]; then
    kill -0 "$(cat $pidfile)" 2> /dev/null
    if [ $? -eq 0 ]; then
        # This process is already running
        logger.sh FATAL "$1 already running - $$"
    fi
fi

printf "%d" $$ > $pidfile

logger.sh INFO "Started -> $(date)"
