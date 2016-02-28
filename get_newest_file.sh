#!/bin/bash

BASEDIR=$1
if [ ! -d "$BASEDIR" ]; then
	echo "$BASEDIR not accessible"
	exit 3
fi

firstbase=$(ls -1td $BASEDIR/*${2}*|head -1)

if [ -d "$firstbase" ]; then
	eval "ls -d1t ${firstbase}/*|head -1"
else
	echo "$firstbase"
fi

