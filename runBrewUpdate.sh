#!/bin/sh
# Update Homebrew and associated packages
# If nothing to do only update on monday

PATH=/usr/local/bin:$PATH:/usr/local/sbin
Logfile=/Users/stu/Logs/`date +%Y%m%d`-runBrewUpdate.log
Tmplog=/tmp/$$.tmp
Appname=BrewUpdate
Host=`hostname`

exec >> $Logfile 2>&1

echo "Running brew update - `date`"

brew update

echo "Running brew upgrade - `date`"
brew upgrade > $Tmplog 2>&1

if [ `wc -l $Tmplog | awk '{print $1}'` != 0 ]; then
	cat $Tmplog >> $Logfile
	growlnotify -n $Appname -m "$Host - Homebrew updates installed"
else
	if [ `date +%w` == "1" ]; then
		growlnotify -n $Appname -m "$Host - Homebrew no updates"
	fi
fi

echo "Brew Upgrades Completed - `date`"
rm $Tmplog



