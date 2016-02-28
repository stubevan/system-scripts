#!/bin/bash 
# Lay Down Sync Status eggs

if [ -f $HOME/.bashrc ]; then
	source $HOME/.bashrc
fi

EXECUTE=0
set -e
rc=0

usage() {
	echo "Usage: $0 {source directory list}"
	exit 1
}

eggfile() {
	echo "SyncStatus.$1.$(echo $2 | awk -F . '{print tolower($1)}').st"
}


# Iterate through the arguments
if [ $# -lt 1 ]; then
	echo "No directories supplied"
	usage
fi

for sourcedir in $*
do
	echo -n "$(date +%Y%m%d-%H%M%S) Protecting -> ${sourcedir}"
	if [ ! -d ${sourcedir} ]; then
		echo " - Invalid directory" && rc=1
		continue
	fi

	syncdir="${sourcedir}/.syncstatus"
	if [ ! -d "${syncdir}" ]; then
		mkdir "${syncdir}"
		if [ $? != 0 ]; then
			echo " - Failed to create egg directory" && rc=1
			continue
		fi
	fi

	dir=$(basename "${sourcedir}" | sed "s/ //g" )
	host=$( hostname | awk -F. '{print $1}' )
	eggfile=$(eggfile "${dir}" $host)
	date --utc +%s > "${syncdir}/${eggfile}"
	if [ $? != 0 ]; then
		echo " - Failed to create egg file"
		rc=1
		continue
	fi
	echo " - OK"
done

exit $rc
