VERSION=1.0.0-beta1
RPMBUILD=rpmbuild



rpmbuild:
	mkdir -p $(RPMBUILD)/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS,tmp}

tarball: rpmbuild
	cd src
	tar cpfz $(RPMBUILD)/SOURCES/cbmon-$(VERSION).tar.gz *


