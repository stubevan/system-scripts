#!/bin/sh
#
# load the specified document into DTPO
# The Group to be loaded into is specfied by the relative path from LOAD_BASE
#
# Default Database is set DEFAULT_DTPO_DATABASE
# Default Tags are None

# The directory can contain a file call DTPO_Settings
# This can override the defaults with contents DTPO_DATABASE= or TAGS=
#
# Redirect our output for debugging purposes
exec >> /Users/stu/Logs/`date +%Y%m%d`-loadDTPO.log 2>&1

echo
echo "loadDTPO -> $*"

LOAD_BASE="$HOME/Documents/Time For Action/Autoload to DTPO/Target Group"
ORPHANS="$HOME/Documents/Time For Action/"

DTPO_DATABASE="/Volumes/DTPO/Home Filing.dtBase2"
DEFAULT_TAGS="Action Required"
DTPO_LOADER=/usr/local/bin/dtpo_loader.py

# File to be loaded is specified in $1
if [ ! $# == 1 ]; then
	echo "Incorrect usage - no source file specified"
	exit 1
fi

SOURCE_FILE="$1"

DOCUMENT_NAME=`basename "$SOURCE_FILE"`
GROUP_NAME=`dirname "$SOURCE_FILE" | sed "s,$LOAD_BASE/,,"`

# check whether the specified directory does exist
if [ ! -d "$LOAD_BASE/$GROUP_NAME" ]; then
	echo "Invalid Group Name $GROUP_NAME"
	exit 1
fi

#See whether there is a settings file
SETTINGS="$GROUP_NAME/DTPO_Settings"
if [ -f "$SETTINGS" ]; then
	TAGS=`grep "TAGS=" "$SETTINGS" | sed 's,^TAGS=,,'`
	X_DATABASE=`grep "DATABASE=" "$SETTINGS" | sed 's,^DATABASE=,,'`
fi

if [ "$TAGS" == "" ]; then
	TAGS="$DEFAULT_TAGS"
fi

TAGS_COMMAND=""
if [ ! "$TAGS" == "" ]; then
	TAGS_COMMAND="-t $TAGS"
fi

if [ -f "$X-DATABASE" ]; then
	DTPO_DATABASE="$DEFAULT_TAGS"
fi

echo "Running -> $DTPO_LOADER -d $DTPO_DATABASE -s $SOURCE_FILE -g $GROUP_NAME $TAGS_COMMAND"
$DTPO_LOADER -d "$DTPO_DATABASE" -s "$SOURCE_FILE" -g "$GROUP_NAME" "$TAGS_COMMAND"
RESULT=$?

if [ $RESULT == 0 ]; then
	/usr/local/bin/trash "$SOURCE_FILE"
else
	mv "$SOURCE_FILE" "$ORPHANS"
fi

exit $RESULT
