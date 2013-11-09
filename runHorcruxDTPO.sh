#/bin/sh
# Usage runHorcux.sh [-d] Daily|Weekly {list of archives}

usage() {
	echo "$0 [-d] Daily|Weekly <list of archives>"
	exit 1
}

. /Users/stu/.bash_profile

echo "Running Horcrux - `date`"

type=$1; shift
if [ ! "$type" == "-d" ]; then
	exec >> /Users/stu/Logs/`date +%Y%m%d`-runHorcruxDTPO.log 2>&1
else
	type=$1; shift
fi

# Check that the type is specifed properly
case "$type" in 
	"Daily" )
		echo "Running Daily Mode"
		;;
	"Weekly" )
		echo "Running Weekly Mode"
		# Only run on sundays
		if [ ! `date +%w` == 0 ]; then
			echo "Not sunday - no run"
			exit 0
		else
			echo "It's sunday - lets do it"
		fi
		;;
	*)
		echo "Fatal: Incorrect type statement - need Daily or Weekly"
		usage
		exit 1
esac

for ARCHIVE in $*
do
	echo `date +%Y%m%d-%H:%M:%S` "Starting backup for $ARCHIVE"
	/usr/local/bin/horcrux -s /Volumes/DTPO auto $ARCHIVE
	echo `date +%Y%m%d-%H:%M:%S` "Completed backup for $ARCHIVE"
done

exit $?
