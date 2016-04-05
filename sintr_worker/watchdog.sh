#!/bin/sh
TIMEOUT=$1
FILE=$2
PID=$3
echo "watchdog: timeout=$TIMEOUT file=$FILE pid=$PID"
sleep 5
SIZE=0
while true
do
   sleep 5 # Delay between tests
   NEW_SIZE=$(stat -c%s "$FILE")
   if [ "$NEW_SIZE" -eq "$SIZE" ]
   then
      echo "watchdog-diag: '$FILE' unchanged; $SIZE"
      # Await max timeout period
      sleep $TIMEOUT
      NEW_SIZE=$(stat -c%s "$FILE")
      if [ "$NEW_SIZE" -eq "$SIZE" ]
      then
        # File was unchanged, shutdown process
        echo "watchdog-diag: killing '$PID'"
        kill $PID || sleep 3 && kill -9 $PID
        exit
      fi
   fi
   echo "watchdog-diag: '$FILE' changed; $SIZE..$NEW_SIZE"
   SIZE=$NEW_SIZE
done
