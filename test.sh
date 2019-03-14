#!/usr/bin/env bash

#===============================================================================
#
#          FILE:  test.sh
# 
#         USAGE:  ./test.sh 
# 
#   DESCRIPTION:  
# 
#       OPTIONS:  ---
#  REQUIREMENTS:  ---
#          BUGS:  ---
#         NOTES:  ---
#        AUTHOR:  Stu Bevan (SRB), stu@badgers-place.me.uk
#       COMPANY:  The Badgers
#       VERSION:  1.0
#       CREATED:  26/03/2016 17:09:08 JST
#      REVISION:  ---
#===============================================================================

. ./badger_setenv.sh $0

parse_option_specification "a!apple!Y!fruit!Test Thingy!Y" 
parse_options  "$@"

log DEBUG "fruit -> $fruit"

log INFO "We are here!"
