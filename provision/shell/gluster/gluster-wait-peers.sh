#!/bin/bash

set -e

NUM_NODES="$1"
TIMEOUT=$2

echo "Waiting for $NUM_NODES peers."

for count in $(seq 1 ${TIMEOUT})
do
  PEERS=$(gluster pool list | grep -v ^UUID | wc -l)
  [ "$PEERS" = "$NUM_NODES" ] && {
    echo "Done waiting: $NUM_NODES peers connected."
    exit 0
  } || {
    sleep 1
  }
done

echo "TIMEOUT waiting for $NUM_NODES peers."
exit 1
