#!/bin/bash

AVAILABLE_HOSTS=$(grep "\." pi-hosts.txt | awk '{print $2}' | cut -d "=" -f2)
# test connection so that it can be accepted
for HOST in $AVAILABLE_HOSTS; do
  echo "check initial connection"
  ssh-keygen -R $HOST
  ssh-keyscan $HOST >> ~/.ssh/known_hosts
done
