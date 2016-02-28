#!/bin/bash

# Create the syncstatus files used to monitor backups and synchronisations

# Setenv prog has to be in the same directory the script is run from
rundir=$(dirname $0)
. ${rundir}/badger_setenv.sh $0

logger.sh INFO "Reading from $1"

IFS=$'\n'
for file in `cat $1`
do
	logger.sh INFO "running syncstatus.sh for $file"
	syncstatus.sh -d "$file"
done

logger.sh INFO "Completed"
