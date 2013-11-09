#/bin/sh
#
#	Take the parameters as a list and ensure that that the hidden attribute
#	is set.  Will most likely be run as root

exec >> /Users/stu/Logs/`date +%Y%m%d`-keepFilesHidden.log 2>&1

PATH=$PATH:/usr/local/bin

echo "Running keepFilesHidden - `date` on $*"

if [ $# == 0 ]; then
	echo "FATAL -> Need at least one directory!!!"
	exit 1
fi

ARGLIST=""

for directory in $*
do
	if [ "$ARGLIST"	== "" ]; then
		ARGLIST="$directory "
	else
		ARGLIST="$ARGLIST -o $directory "
	fi
done

find / -name "$ARGLIST" -print -exec chflags hidden {} \;

echo "Completed keepFilesHidden - `date` on $*"
exit 0
