#!/bin/bash

# standardised way of setting logfile names

echo "/usr/local/log/$(date +%Y%m%d)-$(basename $1 | sed "s/\.sh$//").log"
