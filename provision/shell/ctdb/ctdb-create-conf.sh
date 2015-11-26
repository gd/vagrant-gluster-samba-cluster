#!/bin/bash

set -e

BACKUP_SUFFIX=".orig.$(date +%Y%m%d-%H%M%S)"

RECLOCKDIR="$1"
mkdir -p ${RECLOCKDIR}
RECLOCKFILE=${RECLOCKDIR}/reclock

PUBLIC_ADDRESSES_FILE=/etc/ctdb/public_addresses
NODES_FILE=/etc/ctdb/nodes

FILE=/etc/sysconfig/ctdb
test -f ${FILE} || touch ${FILE}
cp -f -a ${FILE} ${FILE}${BACKUP_SUFFIX}

echo -n > ${FILE}
cat <<EOF >> ${FILE}
CTDB_NODES=${NODES_FILE}
#CTDB_PUBLIC_ADDRESSES=${PUBLIC_ADDRESSES_FILE}
CTDB_RECOVERY_LOCK=${RECLOCKFILE}
CTDB_MANAGES_SAMBA="yes"
CTDB_SAMBA_SKIP_SHARE_CHECK="yes"
#CTDB_MANAGES_WINBIND="yes"
EOF
