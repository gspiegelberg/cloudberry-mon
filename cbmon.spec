# Don't try fancy stuff like debuginfo, which is useless on binary-only
# packages. Don't strip binary too
# Be sure buildpolicy set to do nothing
%define        __spec_install_post %{nil}
%define          debug_package %{nil}
%define        __os_install_post %{_dbpath}/brp-compress

Summary: Cloudberry monitoring
Name: cbmon
Version: 1.0.0
Release: 1
License: Apache License Version 2.0
Group: Development/Tools
SOURCE0 : %{name}-%{version}.tar.gz
URL: http://company.com/

BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

%description
%{summary}

%prep
%setup -q

%build
# Empty section.

%install
rm -rf %{buildroot}
mkdir -p  %{buildroot}

# in builddir
cp -a * %{buildroot}


%clean
rm -rf %{buildroot}


%files
%defattr(-,root,root,-)
%config(noreplace) %{_sysconfdir}/%{name}/%{name}.conf
%{_bindir}/*

%changelog
* Thu Apr 24 2009  Elia Pinto <devzero2000@rpm5.org> 1.0-1
- First Build

