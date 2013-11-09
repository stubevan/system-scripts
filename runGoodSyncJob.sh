#/bin/sh

# Read jobs from Goodsync conf file and see if there are any which need to be
# run manually
JOBS_FILE=/Users/stu/.goodsync/jobs.tic
TRIGGER_LINE="Jobs Below Triggered Externally"
JOBS_TO_RUN=/tmp/gsjobs.$$
TMP_LOG_FILE=/tmp/gslog.$$

exec >> /Users/stu/Logs/`date +%Y%m%d`-runGoodSync.log 2>&1

echo "Running timed GoodSync jobs - `date` - Job $1"

# extract the jobs
cat $JOBS_FILE | awk "
BEGIN { triggered=0 } 
{ if (triggered!=0) { print \$0 } }
/$TRIGGER_LINE/ { triggered = 1 } " | awk -F: '{print $3}' | awk -F\| '{print $1}' > $JOBS_TO_RUN


for job in `cat $JOBS_TO_RUN`
do
	echo "-- Starting $job - `date`"
	/Applications/GoodSync.app/Contents/Resources/gsync sync "$job" > $TMP_LOG_FILE 2>&1

	cat $TMP_LOG_FILE
	echo "-- Completed $job - `date`"
done

rm $JOBS_TO_RUN
rm $TMP_LOG_FILE

exit 0
