set -e

INSTALL="$@"

echo "Installing software [${INSTALL}] ..."

yum -y makecache fast

yum -y install ${INSTALL}
