#!/bin/sh

# We sometimes end up with stuff in Trash which is owned by root - which means that Hazel can't
# clean it.  Simple script which will return things to the rightful order
# Script takes one parameter which is the user name in question
# note that the script requires the user running it to have sudo rights on chown within the trash directory

CHOWN="/usr/sbin/chown -h"

# Set up the environment and the logging
. /usr/local/bin/badger_setenv.sh $0

usage() {
	logger.sh FATAL "Usage: $0 user"
	exit 1
}

if [ $# != 1 ]; then
	usage
fi

# Get the user and check it's valid
user=$1
id $user > /dev/null 2>&1
if [ $? != 0 ]; then
	logger.sh FATAL "User $user does not exist"
	exit 1
fi

TRASH=/Users/$user/.Trash
if [ ! -d $TRASH ]; then
	logger.sh FATAL "Trash directory $TRASH does not exist"
	exit 1
fi

sudo_command="$CHOWN $user $TRASH"

# check that we have the requisite sudo permissions
if [ $( sudo -l | grep -c "${sudo_command}" ) != 1 ]; then
	echo 
	logger.sh FATAL "You dont have the requisite super powers."
	echo "        Add the following line to sudoers:"
	echo
	echo "$user ALL=(ALL) NOPASSWD: $CHOWN $user $TRASH/*"
	echo
	exit 1
fi

# Finally - do the business
find $TRASH ! -user $user -print -exec sudo $CHOWN $user {} \;
exit $?
