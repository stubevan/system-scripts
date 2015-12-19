#!/bin/bash

if [ -f $HOME/.bashrc ]; then
	source $HOME/.bashrc
fi


exec >> $(getlogfilename.sh "$0") 2>&1

echo "`date`: Reading from $1"

IFS=$'\n'
for file in `cat $1`
do
	echo "`date`: running syncstatus.sh for $file"
	syncstatus.sh -d "$file"
done

echo "`date`: Completed"
