Name:           cbmon
Version:        %{_version}
Release:        %{_release}%{?dist}
Summary:        Cloudberry/Greenplum/EDB Warehouse-PG monitoring

License:        Apache License Version 2.0
URL:            https://github.com/gspiegelberg/cloudberry-mon
Source0:        cbmon-%{version}-%{release}.noarch.tar.gz

BuildArch:      noarch
Requires:       python3 >= 3.6
Requires:       sysstat >= 11.7.3

%description
Cloudberry Monitoring (cbmon) is a set of scripts & schema to permit
observability of one or many CloudberryDB / EDB Warehouse-PG / Greenplum
clusters.

%prep
%setup -q

%build
# No build steps needed for pure Python scripts

%install
[ -f /usr/local/cloudberry-db/greenplum_path.sh -o -f /usr/local/greenplum-db/greenplum_path.sh -o -f /usr/local/cloudberry-db/cloudberry_path.sh -o /usr/local/cloudberry-db/cloudberry-env.sh ] || (echo 'cannot find path script'; exit 1)
python3 -c "import sys; assert sys.version_info >= (3, 6), 'Python 3.6+ is required'"
#python3 -c "import configparser" || (echo 'Missing python3 module configparser'; exit 1)
#python3 -c "import logging" || (echo 'Missing python3 module logging'; exit 1)
#python3 -c "import multiprocessing" || (echo 'Missing python3 module multiprocessing'; exit 1)
#python3 -c "import pika" || (echo 'Missing python3 module pika'; exit 1)
#python3 -c "import platform" || (echo 'Missing python3 module platform'; exit 1)
#python3 -c "import psycopg2" || (echo 'Missing python3 module psycopg2'; exit 1)
mkdir -p %{buildroot}/usr/local/cbmon
cp -r * %{buildroot}/usr/local/cbmon/

%post
if [ $( awk -F: '/^gpadmin/ {print $1}' /etc/passwd ) = "gpadmin" ]; then
	chown -R gpadmin:gpadmin /usr/local/cbmon
fi


%files
# %license LICENSE
# %doc README.md
/usr/local/cbmon/*
%config(noreplace) /usr/local/cbmon/etc/config
%config(noreplace) /usr/local/cbmon/etc/config.ini

%changelog
* Tue Apr 22 2025 Greg Spiegelberg <gspiegel@mountain.com>
- Initial release

