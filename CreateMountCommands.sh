#!/bin/sh

exec >> /Users/stu/Logs/`date +%Y%m%d`-CreateMountCommands.log 2>&1

# Create a series of mount unmount commands for use by 
# ChronoSync, GoodSync and SyncStatus

CONFIG_FILE=${HOME}/etc/BackupSupport.conf
TARGET_DIR=${HOME}/bin/BackupSupport
TEMPLATE=${HOME}/etc/MountTemplate

if [ $# -eq 3 ]; then
	# We're in debug mode
	CONFIG_FILE=$1
	TEMPLATE=$2
	TARGET_DIR=$3
fi

echo "CONFIG_FILE -> $CONFIG_FILE"
echo "TEMPLATE -> $TEMPLATE"
echo "TARGET_DIR -> $TARGET_DIR"

if [ ! -d "$TARGET_DIR" ]; then
	echo "Creating Target Dir"
	mkdir -p "$TARGET_DIR"
fi

if [ ! -r "$CONFIG_FILE" ]; then
	echo "Missing Config file -> $CONFIG_FILE"
	exit 1
fi

if [ ! -r "$TEMPLATE" ]; then
	echo "Missing Template file -> $TEMPLATE"
	exit 1
fi

#Clean out the target directory
rm $TARGET_DIR/*

for line in `cat "$CONFIG_FILE" | grep "^[^\#].*:.*:"`
do
	echo "Config Line -> $line"
	
	TargetHost=`echo $line | awk -F: '{print $1}'`
	VolumeName=`echo $line | awk -F: '{print $2}'`
	DeviceName=`echo $line | awk -F: '{print $3}'`

	echo "Creating scripts for $TargetHost, $VolumeName, $DeviceName"
	
	for Command in mount unmount 
	do	
		target_file=$TARGET_DIR/${Command}${TargetHost}${VolumeName}.sh

		echo "Creating $target_file"
		if [ $Command == "unmount" ]; then
			Command="unmount -force"
		fi

		sed -e "s,\<TargetHost\>,$TargetHost,g" \
			-e "s,\<Command\>,$Command,g" \
			-e "s,\<DeviceName\>,$DeviceName,g" \
			-e "s,\<GenereatedDate\>,`date`,g" \
			"$TEMPLATE" > "$target_file"
		chmod 700 "$target_file"
	done
done

