#!/bin/bash

# set selinux to permissive and disable it on next boot

set -e

setenforce permissive

BACKUP_SUFFIX=".orig.$(date +%Y%m%d-%H%M%S)"

FILE=/etc/selinux/config
test -f ${FILE} && {
  sed -i${BACKUP_SUFFIX} -e 's/^SELINUX=.*$/SELINUX=disabled/g' ${FILE}
} || {
  cat <<EOF > ${FILE}
SELINUX=disabled
EOF
}

touch ${FILE}
