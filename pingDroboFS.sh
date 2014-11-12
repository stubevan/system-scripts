#!/bin/sh

exec >> /Volumes/home-encrypted/stu/Logs/`date +%Y%m%d`-pingDroboFS.log 2>&1

date

export SSH_AUTH_SOCK=$( ls -1rt /tmp/launch*/Listeners | sed -n '$p' )

ssh -p 20014 theset.badgers-place.me.uk /mnt/DroboFS/home/stu/bin/motherrang.sh /mnt/DroboFS/home/stu/.motherrang

