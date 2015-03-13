#!/bin/bash

# set selinux to permissive and disable it on next boot

set -e

GETENFORCE="$(getenforce 2> /dev/null)"

[ "${GETENFORCE}" = "Disabled" ] && {
  echo "Selinux already disabled."
} || {
  echo "Setting selinux policy to permissive for this session."
  setenforce permissive
}

BACKUP_SUFFIX=".orig.$(date +%Y%m%d-%H%M%S)"

echo "Disabling selinux permanently."
FILE=/etc/selinux/config
test -f ${FILE} && {
  sed -i${BACKUP_SUFFIX} -e 's/^SELINUX=.*$/SELINUX=disabled/g' ${FILE}
} || {
  cat <<EOF > ${FILE}
SELINUX=disabled
EOF
}

touch ${FILE}
