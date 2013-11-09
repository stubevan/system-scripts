#!/bin/sh
#
# Script to aid installation of scripts and executables.  
# It will also clean up if stuff is deleted - something I dont think
# make can do
#
# script is run in the source directory and expects a file called AutoMake.conf
# This has:
# TARGET=....   Sets the target for the following files.  Can be restated at
#		any time
# You can also optionally add:
# HOST=... which will limit the hosts the install # will run on
# SUDO=1 | 0 specify whether SUDO needed
# list of source files
#
# it takes one optional paramater 'install' which forces the installation
# else it runs in safe mode

COMMANDS=/tmp/`basename $0`.tmp

if [ ! -f "AutoMake.conf" ]; then
	echo "FATAL - No AutoMake.conf file"
fi

INSTALL=0
if [ $# == 1 ]; then
	if [ $1 == 'install' ]; then
		INSTALL=1
	fi;
fi

if [ $INSTALL == 0 ]; then
	echo "Running in SAFE mode"
else
	echo "Install"
fi

# Get ancillary stuff
HOST=`awk -F= '/^HOST/ {print $2}' AutoMake.conf`
SUDO=`awk -F= '/^SUDO/ {print $2}' AutoMake.conf`
TARGET=`awk -F= '/^TARGET/ {print $2}' AutoMake.conf`

if [ ! "$HOST" == "" -a ! "$HOST" == `hostname` ]; then
	echo "FATAL - Can only be run on host -> $HOST"
	exit
fi

if [ "$SUDO" == 1 ]; then
	if [ ! `id -u` == 0 ]; then
		echo "FATAL - Needs to be run as root"
		exit 1
	fi
fi

if [ "$TARGET" == "" ]; then
	echo "FATAL - No Target specified"
	exit 1
fi
	
# Now produce the list of commands to be executed
IFS=$'\n'
for target in `awk -F= 'NF == 2 { if ($1 == "TARGET") target = $2 } NF == 1 { printf("%s/%s\n", target, $0); }' AutoMake.conf`
do
	source=`basename "$target"`
	# check for deletion
	if [ ! -f "$source" -a -f "$target" ]; then
		echo "chmod 755 \"$target\""
		echo "rm -f \"$target\""
	else

		# Check for new installation
		if [ -f "$source" -a ! -f "$target" ]; then
			echo "cp -p \"$source\" \"$target\""
			echo "chmod 555 \"$target\""
		#else

			# Check that the target isn't newer than the source - not that that
			# would ever happen ;-)
			#if [ $source -ot $target ]; then
			#	echo "Fatal: $target is newer than $source!!!  Results of diff ->" 1>&2
			#	diff $source $target 1>&2
			#	exit 1
			#fi
		fi
	fi

	# check for update
	if [ -f "$source" -a -f "$target" ]; then
		if  [ "$source" -nt "$target" ]; then
			echo "chmod 755 \"$target\""
			echo "cp -p \"$source\" \"$target\""
			echo "chmod 555 \"$target\""
		fi
	fi
done > $COMMANDS

echo "Commands ->"
cat $COMMANDS | grep -v chmod

if [ $INSTALL == 1 ]; then
	sh $COMMANDS
fi

rm $COMMANDS
exit 0
