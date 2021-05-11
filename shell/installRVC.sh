#!/bin/bash
# Author: William Lam
# Website: www.williamlam.com
# Product: VMware vMA
# Description: Script to install RVC
# Reference: http://www.williamlam.com/2011/04/how-to-install-ruby-vsphere-console-on.html

RUBY_REPO=ftp://ftp.ruby-lang.org/pub/ruby/1.8/ruby-1.8.7.tar.gz
RUBY_GEM_REPO=http://rubyforge.org/frs/download.php/74619/rubygems-1.7.2.tgz
YUM_REPO=/etc/yum.repos.d/CentOS-Base.repo

green='\E[32;40m'
red='\E[31;40m'
cyan='\E[36;40m'

cecho() {
        local default_msg="No message passed."
        message=${1:-$default_msg}
        color=${2:-$green}
        echo -e "$color"
        echo "$message"
        tput sgr0

        return
}

setupYUM() {

cecho "Creating CentOS YUM Repo ${YUM_REPO}" $green
cat > ${YUM_REPO} << __YUM_REPO__
[base]
name=CentOS-5 - Base
mirrorlist=http://mirrorlist.centos.org/?release=5&arch=x86_64&repo=os
gpgcheck=0

#released updates
[updates]
name=CentOS-5 - Updates
mirrorlist=http://mirrorlist.centos.org/?release=5&arch=x86_64&repo=updates
gpgcheck=0

#packages used/produced in the build but not released
[addons]
name=CentOS-5 - Addons
mirrorlist=http://mirrorlist.centos.org/?release=5&arch=x86_64&repo=addons
gpgcheck=0
__YUM_REPO__
}

downloadRuby() {
	cecho "Downloading Ruby from ${RUBY_REPO}" $green
	wget ${RUBY_REPO} > /dev/null 2>&1
	if [[ $? -eq 1 ]] && [[ ! -f ${RUBY_FILENAME} ]]; then
		cecho "Failed to download from ${RUBY_REPO}" $red
		exit 1
	fi
}

downloadRubyGem() {
	cecho "Downloading Ruby GEM from ${RUBY_GEM_REPO}" $green
	wget ${RUBY_GEM_REPO} > /dev/null 2>&1
	if [[ $? -eq 1 ]] && [ ! -f ${RUBY_GEM_FILENAME} ]]; then
        	cecho "Failed to download from ${RUBY_GEM_REPO}" $red
        	exit 1
	fi
}

installRubyDepend() {
	cecho "Installing Ruby dependencies ..."
	yum -y install gcc gcc-c++ zlib-devel openssl-devel readline-devel libxml2 libxml2-devel libxslt libxslt-devel libffi libffi-devel > /dev/null 2>&1
}

installRuby() {
	cecho "Installing ${RUBY_FILENAME}" $green
	tar -zxvf ${RUBY_FILENAME}
	cd $(basename ${RUBY_FILENAME} | sed 's/.tar.gz//g')
	./configure
	make
	make install
	cd ..
}

installRubyGem() {
	cecho "Installing ${RUBY_GEM_FILENAME}" $green
	tar -zxvf ${RUBY_GEM_FILENAME}
	cd $(basename ${RUBY_GEM_FILENAME} | sed 's/.tgz//g')
	ruby setup.rb
}

updateRubyGem() {
	cecho "Updating GEM ..." $green
	gem update --system
	gem install ffi
}

installRVC() {
	cecho "Installing Ruby vSphere Console" $green
	sudo gem install rvc

	if [ ! -f /usr/local/bin/rvc ]; then
		cecho "Failed to install RVC!" $red
	else
		cecho "Successfully installed Ruby vSphere Console!" $cyan
	fi
}

if [ "$(id -u)" != "0" ]; then
        cecho "Please use sudo to run this script!" $red
        exit 1
fi

RUBY_FILENAME=$(basename ${RUBY_REPO})
RUBY_GEM_FILENAME=$(basename ${RUBY_GEM_REPO})

mkdir -p /tmp/rubyinstall
cd /tmp/rubyinstall

setupYUM
downloadRuby
downloadRubyGem
installRubyDepend
installRuby
installRubyGem
updateRubyGem
installRVC

rm -rf /tmp/rubyinstall
