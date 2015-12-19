#!/bin/sh

# Organise CCTV files into meaningful directories

SOURCE=/home/mfc-cam
TARGET=/home/headbadger/cctv

fatal()
{
	echo "FATAL: $*"
	exit 1
}

getData()
{
	file=$(basename $1)
	# get the date and target from the file name
	data=$( echo $file | awk -F_ '
	{
		if (length($3) == 14) {	# Howard Cam
			printf("%d:%s", substr($3, 1, 8), substr($1, 14, length($1)-14));
		} else if (length($2) == 10) { # 1080 Cam
			printf("%02d%02d%02d:%s", substr($2, 1, 4), substr($2, 6, 2), substr($2, 9, 2), $1);
		} else { # Help!!
			printf ("UNKNOWN:UNKNOWN");
		}
	}'
	)
	echo $data
} 

if [ ! -d $TARGET ]; then
	fatal "TARGET $TARGET doesnt exist"
fi

if [ ! -d $SOURCE ]; then
	fatal "SOURCE $SOURCE doesnt exist"
fi

for file in `find $SOURCE -name \*.jpg -print`
do
	DATA=$(getData $file)
			
	FILEDATE=$(echo $DATA | awk -F: '{print $1}')
	LOCATION=$(echo $DATA | awk -F: '{print $2}')

	DESTINATION=$TARGET/$LOCATION/$FILEDATE

	if [ ! -d $DESTINATION ]; then
		mkdir -p $DESTINATION
	fi

	mv "$file" $DESTINATION
done

