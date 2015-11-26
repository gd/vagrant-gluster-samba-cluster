#!/bin/bash

set -e

BACKUP_SUFFIX=".orig.$(date +%Y%m%d-%H%M%S)"

NODES_IPS="$@"

FILE=/etc/ctdb/nodes
test -f ${FILE} || touch ${FILE}
cp -f -a ${FILE} ${FILE}${BACKUP_SUFFIX}

echo -n > ${FILE}
for IP in ${NODES_IPS}
do
  echo "$IP" >> ${FILE}
done
