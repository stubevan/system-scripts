#!/bin/sh

cd /Users/stu/.Trash

if [ ! `pwd` == '/Users/stu/.Trash' ]; then
	exit 1
fi 

IFS=$'\n'
for x in `ls -ld * | awk '$3 != "stu" { for (i=9; i<=NF; i++) printf("%s ", $i); print ("\n") }'`
do
	chown -R stu $(echo $x | sed 's/ $//')
done
