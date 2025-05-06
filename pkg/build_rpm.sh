#!/bin/bash

CWDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DIR="$CWDIR"

VERSION=0.9
RELEASE=1
ARCH=noarch
TARBALL="cbmon-${VERSION}-${RELEASE}.el8.noarch.tar.gz"

# Reset & prep
BUILDROOT="/tmp/package-build"
rm -rf ${BUILDROOT}
mkdir -p ${BUILDROOT}/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

# Create source file
SRCBASE="/tmp/cbmon-${VERSION}"
# -${RELEASE}.${ARCH}"
SRCDIR="${SRCBASE}"
rm -rf ${SRCBASE}
mkdir -p ${SRCDIR}
cp -r ../src/* ${SRCDIR}
pushd /tmp

# Clean up
rm -rf cbmon-${VERSION}/usr/local/cbmon/alters/postgresql/rinse-repeat cbmon-${VERSION}/usr/local/cbmon/wip

tar cpfz ${DIR}/${TARBALL} cbmon-${VERSION}
popd
rm -rf ${SRCBASE}

cp -f ${DIR}/${TARBALL} ${BUILDROOT}/SOURCES/

cp -f ${DIR}/cbmon.spec ${BUILDROOT}/SPECS/

rpmbuild -bb ${BUILDROOT}/SPECS/cbmon.spec --define "%_topdir ${BUILDROOT}"

#  --define "debug_package %{nil}"

cp -f ${BUILDROOT}/RPMS/noarch/*.rpm ${CWDIR}

