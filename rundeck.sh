#!/bin/bash

# Setenv prog has to be in the same directory the script is run from
rundir=$(dirname $0)
. ${rundir}/badger_setenv.sh $0

#start rundeck

cd /usr/local/rundeck
java -XX:MaxPermSize=1024M -Drundeck.jetty.connector.forwarded=true -Dserver.web.context=/ -Dserver.http.host=127.0.0.1 -jar rundeck-launcher-latest.jar

# We should never get here
/usr/local/bin/pushover.sh -p 1 -t "System Alert" "MrBadger: Unexpected exit of rundeck"
