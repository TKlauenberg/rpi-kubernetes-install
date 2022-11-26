#!/bin/bash

basepath="$(dirname "$(readlink -f "$0")")"

AVAILABLE_HOSTS=$(grep "\." $basepath/../pi-hosts.txt | awk '{print $2}' | cut -d "=" -f2)
for HOST in $AVAILABLE_HOSTS; do
  echo "Working on host $HOST"
  scp -r root@$HOST:/var/log $basepath/log/$HOST &
done

exit

