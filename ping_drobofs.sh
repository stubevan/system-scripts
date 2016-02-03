#!/bin/bash
#
# Script to help keep the DroboFS ssh daemon working

. badger_setenv.sh $0

export SSH_AUTH_SOCK=$( ls -1rt /tmp/launch*/Listeners | sed -n '$p' )

ssh drobofs.badgers-place.me.uk /mnt/DroboFS/home/stu/bin/motherrang.sh /mnt/DroboFS/home/stu/.motherrang

exit 0

