#!/bin/bash

AVAILABLE_HOSTS=$(grep "\." pi-hosts.txt | awk '{print $2}' | cut -d "=" -f2)
# test connection so that it can be accepted and then do all installments parallel
# for HOST in $AVAILABLE_HOSTS; do
#   echo "check initial connection"
#   ssh -t root@$HOST 'echo "working"'
# done
for HOST in $AVAILABLE_HOSTS; do
  echo "Working on host $HOST"
  ssh-keyscan -H $HOST >> ~/.ssh/known_hosts
  ssh -t root@$HOST 'setup-ntp -c chrony; setup-apkrepos -f; apk update; apk add python3' &
done
exit