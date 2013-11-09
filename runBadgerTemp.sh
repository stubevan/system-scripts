#/bin/sh

exec >> /Users/stu/Logs/`date +%Y%m%d`-runBadgerTemp.log 2>&1

echo "Running Badger Temp - `date`"

/Users/stu/src/utilties/BadgerTemp.py $1
res=$?
echo "BadgerTemp completed  - `date`"
exit $res
