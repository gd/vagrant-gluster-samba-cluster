#!/bin/bash

set -e

DEVICE=$1
PARTDEV=${DEVICE}1
DISKDEV="/dev/${DEVICE}"
DISKPARTDEV="/dev/${PARTDEV}"
#EXPORT_BASEDIR=$2
#MOUNTP=${EXPORT_BASEDIR}/${PARTDEV}
MOUNTP=$2
BRICK_PATH_SUFFIX=$3
BRICKD=${MOUNTP}/${BRICK_PATH_SUFFIX}

BACKUP_SUFFIX=".orig.$(date +%Y%m%d-%H%M%S)"

parted -s ${DISKDEV} print > /dev/null 2>&1 && {
  echo "Label exists on ${DISKDEV}."
} || {
  echo "Creating label on ${DISKDEV}."
  parted -s ${DISKDEV} mklabel msdos
}

parted -s ${DISKDEV} print 1 > /dev/null 2>&1 && {
  echo "Partition ${DISKPARTDEV} exists."
} || {
  echo "Creating partition ${DISKPARTDEV}."
  parted -s ${DISKDEV} mkpart primary 1 100%
}

blkid -s TYPE ${DISKPARTDEV} | grep -q -s 'TYPE="xfs"' && {
  echo "Partition ${DISKPARTDEV} contains xfs file system."
} || {
  echo "Creating xfs filesystem on ${DISKPARTDEV}."
  mkfs.xfs -f ${DISKPARTDEV}
}

mkdir -p ${MOUNTP}

FILE=/etc/fstab

grep -q -s ${DISKPARTDEV} ${FILE} && {
  echo "Mount entry for ${DISKPARTDEV} is present in ${FILE}."
} || {
  echo "Creating mount entry for ${DISKPARTDEV} in ${FILE}."
  test -f ${FILE} || touch ${FILE}
  cp -f -a ${FILE} ${FILE}${BACKUP_SUFFIX}
  cat <<EOF >> ${FILE}
${DISKPARTDEV} ${MOUNTP} xfs defaults 0 0
EOF
}

mount | grep ${MOUNTP} && {
  echo "${MOUNTP} is already mounted."
} || {
  echo "Mounting ${MOUNTP}."
  mount ${MOUNTP}
}

mkdir -p ${BRICKD}
