#!/bin/sh

# Alternative startup script to make sure everything happens in the right order
# looks for a file in ~/etc call $HOST.login which contains a list of Applications
# if the Name doesn't begin with / then it looks in /Applications

exec >> /Users/stu/Logs/`date +%Y%m%d`-badgerLogin.log 2>&1

HOSTNAME=`hostname | awk -F. '{print $1}'`
CONFIGFILE=$HOME/etc/${HOSTNAME}.login
IFS=$'\n'

for app in `cat $CONFIGFILE`
do
	FIRSTCHAR=`echo $app | cut -c1`
	if [ $FIRSTCHAR = '/' ]; then
		APP=$app
	else
		APP=/Applications/$app
	fi

	echo "Starting ${APP}"
	# See if it's an app
	if [ -d ${APP} ]; 	then
		open -g "${APP}"
		APPNAME=`basename $APP | awk -F. '{print $1}'`
		osascript -e "tell application \"System Events\" to set visible of application process \"${APPNAME}\" to false"
	else
		# It's a prog or script so run it - the script has to take care of backgrounding anything
		$app
	fi

	sleep 1

done

# Now that we're done the last thing to do is to unload ourselves from launchctl
# or the next load on login will fail
PID=$$
echo "Clean up launchctl - looking for pid $PID"
OURNAME=`launchctl list | awk -v pid=$PID '$1==pid {print $3}'`
echo "We're called $OURNAME"
launchctl remove $OURNAME

