#/bin/sh
# run all of the Horcrux jobs in ~/.horcrux

. /Users/stu/.bash_profile

for ARCHIVE in `ls ~/.horcrux/*config | awk -F\/ '{print $NF}' | cut -d\- -f 1`
do
	exec >> /Users/stu/Logs/`date +%Y%m%d`-runHorcrux.${ARCHIVE}.log 2>&1
	echo `date +%Y%m%d-%H:%M:%S` "Starting backup for $ARCHIVE"
	/usr/local/bin/horcrux auto $ARCHIVE
	echo `date +%Y%m%d-%H:%M:%S` "Completed backup for $ARCHIVE"
done

exit $?
