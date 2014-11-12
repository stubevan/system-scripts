#!/bin/sh

BACKUP_DATE=$(date +%Y%M%d)
rsync -aiv --human-readable --progress --delete --backup --backup-dir="/Users/stu/Local/Backups/The\ Bells/Backups/${BACKUP_DATE}/" -e 'ssh'  monsters:/volume1/BellNet/ "/Users/stu/Local/Backups/The Bells/Monsters"
