#!/bin/bash

set -e

VOLNAME=$1
shift
MOUNTPT=$1
shift

MOUNTDEV="127.0.0.1:/${VOLNAME}"

mkdir -p ${MOUNTPT}

BACKUP_SUFFIX=".orig.$(date +%Y%m%d-%H%M%S)"

FILE=/etc/fstab

grep -q -s "${MOUNTPT}" ${FILE} || {
  test -f ${FILE} || touch ${FILE}
  cp -f -a ${FILE} ${FILE}${BACKUP_SUFFIX}

  cat <<EOF >> ${FILE}
${MOUNTDEV} ${MOUNTPT} glusterfs defaults,selinux 0 0
EOF
}

mount | grep -q -s ${MOUNTPT} && {
  echo "${MOUNTPT} is already mounted."
} || {
  echo "Mounting ${MOUNTPT}."
  mount ${MOUNTPT}
}
