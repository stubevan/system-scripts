#!/bin/sh
sourceDir=/Users/stu/Documents/BooksToClean/

IFS=$'\n'
for file in `grep "Processing file: " $1 | awk -F : '{print $2}' | sed "s/ //g"`
do
	target=${sourceDir}${file}
	if [ -e ${target} ]; then
		echo ${target} >> /Users/stu/Logs/clean.log
		rm ${target}
	fi
done
