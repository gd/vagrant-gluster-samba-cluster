#!/bin/bash

set -e

PEER_IPS="$@"

echo "peer probing for [${PEER_IPS}]"

for PEER_IP in ${PEER_IPS}
do
  echo "peer probing for '${PEER_IP}'"

  for COUNT in $(seq 1 120)
  do
    gluster peer probe ${PEER_IP} 2> /dev/null && {
      echo "reached node '${PEER_IP}'"
      break
    } || {
      sleep 1
    }
  done

  gluster peer probe ${PEER_IP} 2> /dev/null || {
    echo "did not reach node '${PEER_IP}' - stopping here"
    break
  }
done
exit 0
