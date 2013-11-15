#/bin/sh

# Mount the encrypted filesystems specified in the arguments 
# if no arguments given then apply to everything in the config file
# config file default is ~/etc/host.encfs

# usage mountEncfs mount | unmount  ( filesystem }

. $HOME/.bash_profile
EXEC_NAME=$0
ID=$( id -nu )
CONFIG_FILE="$HOME/etc/$( hostname | cut -d. -f1 ).encfs"

if [ ! -f $CONFIG_FILE ]; then
	echo "FATAL: Config file $CONFIG_FILE not readable"
	exit 1
fi

usage() {
	echo "Usage: $EXEC_NAME mount | unmount { filesystem }"
	echo "	If no file system specified all entries in $CONFIG_FILE will be processed"
	echo "	If no no action and no file system specified then mount all"
	exit 1
}

exec_mount() {
	# mount the specified filesystem
	# get the password
	name=$1
	encrypted_file=$2
	mount_point=$3
	password_key="encfs.$1"

	#checks first
	if [ ! -d $encrypted_file ]; then
		echo "WARNING: Encrypted file $encrypted_file does not exist - $name not mounted"
		return  1
	fi

	if [ ! -d $mount_point ]; then
		echo "WARNING: mount point $mount_point does not exist - $name not mounted"
		return 1
	fi

	# check it's not aready mounted
	if [ "`mount -t osxfusefs | cut -c19- | cut -d\( -f1 | sed 's/ $//' | grep \"$mount_point\"`" == $mount_point ]; then
		echo "$mount_point already mounted - ignoring"
		return 0
	fi

	# now get the password
	password=$( security find-generic-password -a $ID -s $password_key -w )
	if [ $? != 0 -o "$password" == "" ]; then
		echo "WARNING: No password found for $name - not mounted"
		return 1
	fi

	#attempt the mount
	echo "${password}"  | encfs $encrypted_file $mount_point --stdinpass
	if [ $? != 0 ]; then
		echo "WARNING: mount failed for $name"
		return 1
	fi
}

# process the specified command
processCommand() {
	
	FILESYSTEM=$1
	chk=$( awk -F: "\$1==\"$FILESYSTEM\" { print 1 }" $CONFIG_FILE )
	if [ "$chk" != 1 ]; then
		echo "WARNING: filesystem $FILESYSTEM does not exist in $CONFIG_FILE"
		return 1
	fi
	encrypted_file=$( awk -F: "\$1==\"$FILESYSTEM\" {print \$2}" $CONFIG_FILE )
	mount_point=$( awk -F: "\$1==\"$FILESYSTEM\" {print \$3}" $CONFIG_FILE )

	if [ $COMMAND == "mount" ]; then
		exec_mount $FILESYSTEM $encrypted_file $mount_point
	else
		chk=$( mount -t osxfusefs | cut -c19- | cut -d\( -f1 | sed 's/ $//' | grep "$mount_point" )
		# Silently ignore unmounted file systems
		if [ "$chk" == "$mount_point" ]; then
			umount $mount_point
		fi
	fi
}

# Main
COMMAND=$1
if [ "$COMMAND" == "" ]; then
	COMMAND="mount"
else
	shift
fi

if [ $COMMAND != "mount" -a $COMMAND != "umount" ]; then
	echo "FATAL: incorrect command $COMMAND"
	usage
fi

FILESYSTEM=""

# See if a filesystems has been specified
if [ $# == 1 ]; then
	FILESYSTEM=$1

	processCommand $FILESYSTEM
else
	# iterate through the config file

	for name in `awk -F: '/^ *[^#]/ && NF==3 {print $1}' $CONFIG_FILE`
	do	
		processCommand $name
	done
fi
