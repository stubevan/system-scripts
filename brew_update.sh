#!/bin/bash
# Update Homebrew and associated packages

# Set up the environment and the logging
. /usr/local/bin/badger_setenv.sh $0

logger.sh INFO "Running Brew Update"

brew update
if [ ! $? -eq 0 ]; then
	logger.sh FATAL "Brew Update Failed"
	exit 1
fi

# Get list of outdated packages so we can report
outdated=$(brew outdated | awk -F\( '{printf ("%s, "i, $1);}' | sed "s/, $//")

if [ -z "${outdated}"  ]; then
	logger.sh INFO "Brew Update - Nothing to do"
	exit 0
fi

logger.sh ALERT "Upgrading brews -> ${outdated}"

brew upgrade --cleanup

# Check that it all worked
outdated=$(brew outdated)

if [ -n "${outdated}" ]; then
	logger.sh ALERT "Brew update failed"
else
	logger.sh INFO "Brew update completed"
fi

exit 0

