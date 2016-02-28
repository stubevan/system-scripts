#!/bin/bash 
# 
# check that specific image is correctly mounted
# will need sudo access for specific commands and also key chain access
#

echo "`date`: check_image_mount - started"

if [ -f $HOME/.bashrc ]; then
	source $HOME/.bashrc
fi

EXECUTE=0
set -e


usage() {
	echo "Usage: -b {Backup Share} -B { backup mount point } -a { backup user } -i {image path} -M {image mount point}"
	exit 1
}

# Parse single-letter options
while getopts b:B:a:i:M: opt; do
    case "$opt" in
        b) BACKUP_SHARE="$OPTARG"
           ;;
        B) BACKUP_MOUNT="$OPTARG"
           ;;
        a) BACKUP_USER="$OPTARG"
           ;;
        i) IMAGE_PATH="$OPTARG"
           ;;
        M) IMAGE_MOUNT="$OPTARG"
           ;;
    esac
done

# Check the args
if [ "x${BACKUP_SHARE}" == "x" ]; then
	echo "FATAL: Must specify a source host"; exit 3
fi

# get the passwords
BACKUP_HOST=$( dirname ${BACKUP_SHARE} )
IMAGE_FILE=$( basename ${IMAGE_PATH} )


# See if we are already mounted
check_mount=$( /sbin/mount | grep "${BACKUP_SHARE}" | wc -l )
if [ ${check_mount} == 0 ]; then
	echo "`date`: mounting NAS"
	# Need to mount the share
	SHARE_PASSWORD=$( security find-internet-password -w -s ${BACKUP_HOST} -a ${BACKUP_USER} )
	sudo -n /sbin/mount_afp -i  "afp://${BACKUP_USER}:${SHARE_PASSWORD}@${BACKUP_SHARE}" ${BACKUP_MOUNT} 
fi

#  check for the target
check_mount=$( /sbin/mount | grep  "${IMAGE_MOUNT}"  | wc -l)
if [ $check_mount == 0 ]; then
	echo "`date`: mounting image - ${IMAGE_MOUNT}"
	IMAGE_PASSWORD=$( security find-generic-password -w -s ${IMAGE_FILE} )
	printf  '%s\0' "${IMAGE_PASSWORD}" | sudo -n /usr/bin/hdiutil attach -stdinpass "${BACKUP_MOUNT}/${IMAGE_PATH}"
fi

echo "`date`: check_image_mount - ${IMAGE_MOUNT} completed"
exit 0
