#!/bin/bash
# Author: William Lam
# http://www.virtuallyghetto.com/
# Script to install VIX-PERL which requires GCC to be installed

VIX_PERL=/usr/lib/vmware-vix/vix-perl.tar.gz
CENTOS_REPO=/etc/yum.repos.d/centos-base.repo

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
    exit 1
fi

if [ -f ${VIX_PERL} ]; then
   cat > ${CENTOS_REPO} << EOF
[base]
name=CentOS-5 - Base
baseurl=http://mirror.centos.org/centos/5/os/x86_64/
gpgcheck=1
gpgkey=http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-5

[update]
name=CentOS-5 - Updates
baseurl=http://mirror.centos.org/centos/5/updates/x86_64/
gpgcheck=1
gpgkey=http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-5
EOF
   yum -y --nogpgcheck install gcc.x86_64

   cd /usr/lib/vmware-vix/
   tar -zxvf vix-perl.tar.gz
   cd vix-perl
   perl Makefile.PL
   make
   make install
else
   echo "VIX is not installed!"
fi
