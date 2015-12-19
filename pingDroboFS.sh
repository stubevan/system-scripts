#!/bin/bash

exec >> "$(getlogfilename.sh)" 2>&1

date

export SSH_AUTH_SOCK=$( ls -1rt /tmp/launch*/Listeners | sed -n '$p' )

ssh drobofs.badgers-place.me.uk /mnt/DroboFS/home/stu/bin/motherrang.sh /mnt/DroboFS/home/stu/.motherrang

