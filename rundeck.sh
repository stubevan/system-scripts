#!/usr/local/bin/bash

# Setenv prog has to be in the same directory the script is run from
rundir=$(dirname $0)
. ${rundir}/badger_setenv.sh $0


cd /usr/local/rundeck
<<<<<<< HEAD
java -XX:MaxPermSize=1024M -Drundeck.jetty.connector.forwarded=true -Dserver.web.context=/ -Dserver.http.host=127.0.0.1 -jar rundeck-launcher-latest.jar
=======
export RDECK_BASE=/usr/local/rundeck
java -Drundeck.ssl.config=$RDECK_BASE/server/config/ssl.properties -jar rundeck-launcher-latest.war
>>>>>>> Initial-Code-Drop

# We should never get here
/usr/local/bin/pushover.sh -p 1 -t "System Alert" "MrBadger: Unexpected exit of rundeck"
