set -e

INSTALL="$@"

echo "Installing software [${INSTALL}] ..."

yum -y -v makecache fast

yum -y -v install ${INSTALL}
