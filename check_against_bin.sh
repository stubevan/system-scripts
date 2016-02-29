#!/bin/bash

. badger_setenv.sh $0

echo "Checking for files in Master not in /usr/local/bin"

for i in *
do
	gitign=$(grep -c "$i" .gitignore)
	tmpign=$(grep -c "$i" .linuxign)
	if [ $gitign == 0 -a $tmpign == 0 ]; then
		if [ ! -f "/usr/local/bin/$i" ]; then
			echo "$i -> not in /usr/local/bin"
			continue
		fi
		diff "$i" "/usr/local/bin/$i" > $TMPFILE1
		if [ $? != 0 ]; then
			echo
			echo "Checking -> $i"
			echo
			cat $TMPFILE1
			echo
			echo "------"
			echo
		fi
	fi
done

IFS=$'\n'
echo
echo
echo "Checking for files in /usr/local/bin not in Master"
for i in `/usr/bin/find /usr/local/bin -depth 1 ! -type l -print`
do
	file=$(basename "$i")
	tmpign=$(grep -c "$file" .validfile)

	if [ ! -f "../DNS-Updater/$file" -a ! -f "$file" -a ! -f "../nagios-plugins/$file" -a $tmpign == 0 ]; then
		echo "$file"
	fi
done

