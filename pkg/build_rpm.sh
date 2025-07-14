#!/bin/bash

usage() {
	cat << EOHELP
build_rpm.sh -r R -v V -d D
  -r R      release number (required)
  -v V      version number (required)
  -d D      d = { el8 | el9 } (required)
  -h        help
EOHELP
	exit
}

options="r:v:d:h"

while getopts $options opt
do
	case "$opt" in
	d)
		DIST="${OPTARG}"
		SPECFILE=cbmon-${DIST}.spec
		;;
	r)
		RELEASE="${OPTARG}"
		;;
	v)
		VERSION="${OPTARG}"
		;;
	*)
		usage
		;;
	esac
done

if [ ! -f "$SPECFILE" ]; then
	echo "spec file $SPECFILE does not exist"
	usage
fi

CWDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DIR="$CWDIR"

#VERSION=0.9
#RELEASE=1
ARCH=noarch
TARBALL="cbmon-${VERSION}-${RELEASE}.${DIST}.noarch.tar.gz"

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

cp -f ${DIR}/${SPECFILE} ${BUILDROOT}/SPECS/

rpmbuild -bb ${BUILDROOT}/SPECS/${SPECFILE} --define "%_topdir ${BUILDROOT}" \
  --define "_version ${VERSION}" \
  --define "_release ${RELEASE}"

cp -f ${BUILDROOT}/RPMS/noarch/*.rpm ${CWDIR}

