#!/bin/sh

BACKUP_DATE=$(date +%Y%M%d)
rsync -aiv --human-readable --progress --delete -e 'ssh' /Users/stu/Pictures/Brock\ Photo\ Library.aplibrary/ stu@boppybadger.badgers-place.me.uk:"/Volumes/home-RAID/stu/Pictures/Brock\ Photo\ Library.aplibrary"
