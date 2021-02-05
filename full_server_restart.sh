#!/bin/bash

set -e
set -x

cd /var/rwot
touch no_restart.txt
./stop_rwot_server.sh
sleep 5
rm -f skotos.database skotos.database.old

rm no_restart.txt
./start_rwot_server.sh

sleep 1

echo "Server restart complete - you can hit CTRL-C to stop tailing the server output logfile."
tail -f /var/log/dgd/server.out
