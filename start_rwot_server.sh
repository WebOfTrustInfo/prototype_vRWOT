#!/bin/bash

set -e
set -x

cd /var/rwot

if [ -f no_restart.txt ]
then
	exit
fi

if [ -f skotos.database ]
then
    SKOTOS_CMD="/var/dgd/bin/dgd skotos.config skotos.database"
else
    SKOTOS_CMD="/var/dgd/bin/dgd skotos.config"
fi

if ps aux | grep "/var/dgd/bin/dgd skotos.config" | grep -v grep
then
	echo "RWOT DGD server is already running"
else
	echo "RWOT DGD server is not running - restarting"
	$SKOTOS_CMD >>/var/log/dgd/server.out 2>&1 &
fi
