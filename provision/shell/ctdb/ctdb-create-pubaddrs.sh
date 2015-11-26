#!/bin/bash

set -e

BACKUP_SUFFIX=".orig.$(date +%Y%m%d-%H%M%S)"

PUB_IPS="$@"

FILE=/etc/ctdb/public_addresses
test -f ${FILE} || touch ${FILE}
cp -f -a ${FILE} ${FILE}${BACKUP_SUFFIX}

echo -n > ${FILE}
for IP in ${PUB_IPS}
do
  echo ${IP} >> ${FILE}
done
