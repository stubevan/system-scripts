#!/bin/bash

#start rundeck

exec >> /usr/local/log/`date +%Y%m%d`-rundeck.log 2>&1
cd /usr/local/rundeck
java -XX:MaxPermSize=1024M -Drundeck.jetty.connector.forwarded=true -Dserver.web.context=/rundeck -Dserver.http.host=127.0.0.1 -jar rundeck-launcher-latest.jar

# We should never get here
/usr/local/bin/pushover.sh -p 1 -t "System Alert" "MrBadger: Unexpected exit of rundeck"
