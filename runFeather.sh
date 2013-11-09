#/bin/sh

exec >> /Users/stu/Logs/`date +%Y%m%d`-runFeather.log 2>&1

echo "Running Feather - `date`"

/Users/stu/bin/feather -v -v /Users/stu/etc/feather.yaml
res=$?
echo "Feather completed  - `date`"
exit $res
