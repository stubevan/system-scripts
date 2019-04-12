#!/bin/bash
#===============================================================================
#
#          FILE:  system-clean.sh
# 
#         USAGE:  ./system-clean.sh 
# 
#   DESCRIPTION:  Highlights files in the home directory and other nominated 
#				  locations which are not correctly under version control
# 
#       OPTIONS:  ---
#  REQUIREMENTS:  ---
#          BUGS:  ---
#         NOTES:  ---
#        AUTHOR:  Stu Bevan (SRB), stu@mees.st
#       COMPANY:  
#       VERSION:  1.0
#       CREATED:  31/03/2019 18:15:39 CEST
#      REVISION:  ---
#===============================================================================

CONFIG_FILE=$1
exclude_str="\( "

filelist=/tmp/clean_1.$$
yadmlist=/tmp/clean_2.$$

#Start with the home directory
IFS=$'\n'
for dir in $(cat $CONFIG_FILE)
do
	exclude_str="$exclude_str -path \*/$dir -o "
done
exclude_str="$exclude_str -path $HOME/.yadm \) "
FIND="find $HOME $exclude_str -prune -o -exec ls -Fd {} \; | grep -v '/$'"

yadm list -a > $yadmlist
cat $HOME/.yadm/encrypt >> $yadmlist

exclude_str=""
for entry in $(cat $yadmlist)
do
	exclude_str="${exclude_str}${entry}|"
done
exclude_str="${exclude_str}zzzz"

eval $FIND | sed "s,^$HOME/,," | egrep -v "${exclude_str}"
