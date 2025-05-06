Name:           cbmon
Version:        0.9
Release:        1%{?dist}
Summary:        Cloudberry/Greenplum/EDB Warehouse-PG monitoring

License:        Apache License Version 2.0
URL:            https://github.com/gspiegelberg/cloudberry-mon
Source0:        cbmon-%{version}-%{release}.noarch.tar.gz

BuildArch:      noarch
Requires:       python3 >= 3.9

%description
Cloudberry Monitoring (cbmon) is a set of scripts & schema to permit
observability of one or many CloudberryDB / EDB Warehouse-PG / Greenplum
clusters.

%prep
%setup -q

%build
# No build steps needed for pure Python scripts

%install
python3 -c "import sys; assert sys.version_info >= (3, 9), 'Python 3.9+ is required'"
#python3 -c "import configparser" || (echo 'Missing python3 module configparser'; exit 1)
#python3 -c "import logging" || (echo 'Missing python3 module logging'; exit 1)
#python3 -c "import multiprocessing" || (echo 'Missing python3 module multiprocessing'; exit 1)
#python3 -c "import pika" || (echo 'Missing python3 module pika'; exit 1)
#python3 -c "import platform" || (echo 'Missing python3 module platform'; exit 1)
#python3 -c "import psycopg2" || (echo 'Missing python3 module psycopg2'; exit 1)
mkdir -p %{buildroot}/usr/local/cbmon
cp -r * %{buildroot}/usr/local/cbmon/

%files
# %license LICENSE
# %doc README.md
/usr/local/cbmon/*

%changelog
* Tue Apr 22 2025 Greg Spiegelberg <gspiegel@mountain.com> - 0.9-1
- Initial release

