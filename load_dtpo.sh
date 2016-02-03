#!/bin/bash
#
# load the specified document into DTPO
# The Group to be loaded into is specfied by the relative path from LOAD_BASE
#
# Default Database is set DEFAULT_DTPO_DATABASE
# Default Tags are None

# The directory can contain a file call DTPO_Settings
# This can override the defaults with contents DTPO_DATABASE= or TAGS=
#
. badger_setenv.sh $0

logger.sh INFO "loadDTPO -> $*"

ORPHANS="$HOME/Documents/Time For Action/"

DTPO_DATABASE="/Users/stu/Local/DTPO/Home Filing.dtBase2"
DTPO_LOADER=/usr/local/bin/dtpo_loader.py

# File to be loaded is specified in $1
if [ ! $# == 3 ]; then
	echo "Incorrect usage - $0 SourceFile GroupName Tags"
	exit 1
fi

SOURCE_FILE="$1"
DOCUMENT_NAME=`basename "$SOURCE_FILE"`

GROUP_NAME="$2"
TAGS="$3"

echo "Running -> $DTPO_LOADER -d $DTPO_DATABASE -s $SOURCE_FILE -g $GROUP_NAME -t $TAGS"
$DTPO_LOADER -d "$DTPO_DATABASE" -s "$SOURCE_FILE" -g "$GROUP_NAME" -t "$TAGS"
RESULT=$?

if [ $RESULT == 0 ]; then
	/usr/local/bin/trash "$SOURCE_FILE"
else
	mv "$SOURCE_FILE" "$ORPHANS"
fi

exit $RESULT
