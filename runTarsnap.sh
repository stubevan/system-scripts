#/bin/sh

exec >> /Users/stu/Logs/`date +%Y%m%d`-runTarsnap.log 2>&1

echo "Running Tarsnap - `date`"

ARCHIVE=`date +%Y%m%d.%H%M`-BadgerBackups

/usr/local/bin/tarsnap -c -v --checkpoint-bytes 104857600 --keyfile /Users/stu/etc/tarsnap.key --cachedir /Users/stu/.tarsnap --print-stats -f $ARCHIVE --exclude Dropbox/Pictures --exclude Dropbox/.dropbox.cache --exclude src/DownloadedCode --exclude */_gsdata_ /Volumes/DTPO -C /Users/stu etc src Documents Dropbox

res=$?
echo "Tarsnap completed  - `date`"
exit $res
