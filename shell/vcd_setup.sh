#!/bin/bash

# vCloud Director Installation Script
# William Lam
# www.virtuallyghetto.com

cyan='\E[36;40m'
green='\E[32;40m'
red='\E[31;40m'
yellow='\E[33;40m'
notsupported='\E[;31;47m'

cecho() {
	local default_msg="No message passed."
	message=${1:-$default_msg}
	color=${2:-$green}
	echo -e "$color"
	echo "$message"
	tput sgr0

	return 
}

verify() {
	if [ ${UID} -ne 0 ]; then
		cecho "Installer must run as root!" $red
		exit 1
	fi

	if [ ! -f ${ORACLE_EXPRESS_RPM} ]; then
		cecho "Unable to find ${ORACLE_EXPRESS_RPM}!" $red
		exit 1
	fi

	if [ ! -f ${VMWARE_VCD_BIN} ]; then
		cecho "Unable to find ${VMWARE_VCD_BIN}!" $red
		exit 1
        fi

	if [ -z ${IP_ADDRESS_2} ]; then
		cecho "IP_ADDRESS_2 is not defined!" $red
		exit 1
        fi

	cecho "Located VMware vCD BIN: ${VMWARE_VCD_BIN}" $green
	cecho "Located Oracle Express RPM: ${ORACLE_EXPRESS_RPM}" $green
	cecho "Secondary IP Address for ${IP_ADDRESS_2}" $green
	cecho "Would you like to proceed with the installation of VMware vCD ${VCLOUD_VERSION} & Oracle Express ${ORACLE_VERSION} along with configuring secondary IP Address? [y|n]" $yellow
	
	read RESPONSE
	case "$RESPONSE" in [yY]|[yes]|[YES]|[Yes])
		;;
		*) cecho "Quiting installation!" $red
		exit 1
		;;
	esac
}

usage() {
	cecho "vCloud Director Installation Script by William Lam (www.virtuallyghetto.com)" $cyan
	cecho "Invalid input, please supply vcd response file!" $red
	cecho "$0 [vcd.resp]" $green
	exit 1
}

configureYUM() {
	cecho "Configuring YUM repository ..." $cyan 

	YUM_CONF=/etc/yum.repos.d/CentOS-Base.repo
	cat > "${YUM_CONF}" << __YUM_CONF__
[base]
name=CentOS-\$releasever - Base
mirrorlist=http://mirrorlist.centos.org/?release=\$releasever&arch=\$basearch&repo=os
#baseurl=http://mirror.centos.org/centos/\$releasever/os/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-5

#released updates
[updates]
name=CentOS-$releasever - Updates
mirrorlist=http://mirrorlist.centos.org/?release=\$releasever&arch=\$basearch&repo=updates
#baseurl=http://mirror.centos.org/centos/\$releasever/updates/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-5

#packages used/produced in the build but not released
[addons]
name=CentOS-$releasever - Addons
mirrorlist=http://mirrorlist.centos.org/?release=\$releasever&arch=\$basearch&repo=addons
#baseurl=http://mirror.centos.org/centos/\$releasever/addons/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-5

#additional packages that may be useful
[extras]
name=CentOS-$releasever - Extras
mirrorlist=http://mirrorlist.centos.org/?release=\$releasever&arch=\$basearch&repo=extras
#baseurl=http://mirror.centos.org/centos/\$releasever/extras/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-5

#additional packages that extend functionality of existing packages
[centosplus]
name=CentOS-$releasever - Plus
mirrorlist=http://mirrorlist.centos.org/?release=\$releasever&arch=\$basearch&repo=centosplus
#baseurl=http://mirror.centos.org/centos/\$releasever/centosplus/\$basearch/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-5

#contrib - packages by Centos Users
[contrib]
name=CentOS-$releasever - Contrib
mirrorlist=http://mirrorlist.centos.org/?release=\$releasever&arch=\$basearch&repo=contrib
#baseurl=http://mirror.centos.org/centos/\$releasever/contrib/\$basearch/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-5
__YUM_CONF__
}

installPreReqs() {
	YUM_PACKAGES=(java-1.6.0-openjdk-devel.x86_64 ntp alsa-lib bash chkconfig compat-libcom_err coreutils findutils glibc grep initscripts krb5-libs libgcc libICE libSM libstdc libX11 libXau libXdmcp libXext libXi libXt libXtst module-init-tools net-tools pciutils procps redhat-lsb sed tar which)

	for PACKAGE in ${YUM_PACKAGES[*]}
	do
        	cecho "Verifying and installing \"${PACKAGE}"\" $cyan
	        yum -y install "${PACKAGE}" > /dev/null 2>&1
	done

}

disableServices() {
	cecho "Disabling iptables ..." $cyan
	service iptables stop
	chkconfig --level 345 iptables off
	service ip6tables stop
	chkconfig --level 345 ip6tables off

	cecho "Disabling selinux ..." $cyan
	sed -ie 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config

	cecho "Enabling NTP ..." $cyan
	service ntpd start
	chkconfig --level 345 ntpd on

}

createSecondInterface() {
	ETH1_CONF=/etc/sysconfig/network-scripts/ifcfg-eth1

	grep -i "BOOTPROTO=static" ${ETH1_CONF} > /dev/null 2>&1
	if [ $? -eq 1 ]; then
		cecho "Configure secondary interface ..." $cyan
		sed -ie 's/BOOTPROTO=dhcp/BOOTPROTO=static/g' ${ETH1_CONF}
		echo "IPADDR=${IP_ADDRESS_2}" >> ${ETH1_CONF}
		echo "NETMASK=${IP_ADDRESS_2_NETMASK}" >> ${ETH1_CONF}
		ifdown eth1
		ifup eth1
	else 
		cecho "Looks like secondary interface is already configured!" $red
	fi
}

installOracle() {
	if [ ${ORACLE_VERSION} == "10.2.0" ]; then
		ORACLE_HOME_PATH=/usr/lib/oracle/xe/app/oracle/product/${ORACLE_VERSION}/server
	elif [ ${ORACLE_VERSION} == "11.2.0" ]; then
		ORACLE_HOME_PATH=/u01/app/oracle/product/${ORACLE_VERSION}/xe/
	fi
		
	if [ ! -d ${ORACLE_HOME_PATH} ]; then
		cecho "Installing Oracle Express ..." $cyan

		ORACLE_RSP=/tmp/oracle-install-$$.response

		cecho "Creating Oracle Express installation response file in ${ORACLE_RSP}" $cyan
		cat > ${ORACLE_RSP} << __ORACLE__RESPONSE__
${ORACLE_XE_GUI_PORT}
${ORACLE_XE_LISTENER_PORT}
${ORACLE_SYS_PASSWORD}
${ORACLE_SYS_PASSWORD}
y
__ORACLE__RESPONSE__

		rpm -i ${ORACLE_EXPRESS_RPM}

		cecho "Configuring Oracle Express" $cyan
		/etc/init.d/oracle-xe configure < ${ORACLE_RSP}
		cecho "Removing Oracle Express installation response file" $cyan
		rm -f ${ORACLE_RSP}
	else
		cecho "Oracle looks to be installed under ${ORACLE_HOME_PATH}! Skipping Oracle installation" $red
	fi	
}

configureOracle() {
	ORACLE_CONF_SCRIPT=/tmp/oracle_configuration-$$.sh
	if [ ${ORACLE_VERSION} == "10.2.0" ]; then
		ORACLE_HOME=/usr/lib/oracle/xe/app/oracle/product/${ORACLE_VERSION}/server
	elif [ ${ORACLE_VERSION} == "11.2.0" ]; then
		ORACLE_HOME=/u01/app/oracle/product/${ORACLE_VERSION}/xe
	fi
	ORACLE_SID=XE

	cecho "Creating Oracle Configuration Script in ${ORACLE_CONF_SCRIPT} ..." $cyan
	cat > ${ORACLE_CONF_SCRIPT} << __ORACLE_CONF_SCRIPT__
	export ORACLE_HOME=${ORACLE_HOME}
	export ORACLE_SID=XE
	export PATH=$PATH:$ORACLE_HOME/bin

	if [ ! -d "${ORACLE_HOME}/oradata" ]; then
		mkdir -p "${ORACLE_HOME}/oradata"
	fi
	
	sqlplus "/ as sysdba" << EOF
Create Tablespace CLOUD_DATA datafile '${ORACLE_HOME}/oradata/cloud_data01.dbf' size ${TABLESPACE_CLOUD_DATA_SIZE} autoextend on;
Create Tablespace CLOUD_INDX datafile '${ORACLE_HOME}/oradata/cloud_indx01.dbf' size ${TABLESPACE_CLOUD_INDEX_SIZE} autoextend on;
Create user ${ORACLE_VCLOUD_USERNAME} identified by ${ORACLE_VCLOUD_PASSWORD} default tablespace CLOUD_DATA;
grant CONNECT,RESOURCE,CREATE TRIGGER,CREATE TYPE,CREATE VIEW,CREATE MATERIALIZED VIEW,CREATE PROCEDURE,CREATE SEQUENCE,EXECUTE ANY PROCEDURE to vcloud;
EOF
	
__ORACLE_CONF_SCRIPT__
	chown oracle:dba ${ORACLE_CONF_SCRIPT}
	chmod 755 ${ORACLE_CONF_SCRIPT}

	cecho "Executing Oracle Configuration Script ${ORACLE_CONF_SCRIPT} using "oracle" account ... Please be patient and do not Ctrl+C anything" $cyan
	su oracle -c "${ORACLE_CONF_SCRIPT}"

	sleep 15

	cecho "Removing Oracle Configuration Script ${ORACLE_CONF_SCRIPT} ..." $cyan
	rm -f ${ORACLE_CONF_SCRIPT}
}

generateCertificates() {
	HTTP_IP=$(grep IPADDR /etc/sysconfig/network-scripts/ifcfg-eth0 | awk -F "=" '{print $2}')
	CONSOLEPROXY_IP=$(grep IPADDR /etc/sysconfig/network-scripts/ifcfg-eth1 | awk -F "=" '{print $2}')
	HTTP_HOSTNAME=$(host ${HTTP_IP} | awk '{print $5}' | sed 's/.$//g')
	CONSOLEPROXY_HOSTNAME=$(host ${CONSOLEPROXY_IP} | awk '{print $5}' | sed 's/.$//g')

	if [ ! -f /opt/keystore/certificates.ks ]; then
		cecho "Creating keystore certificate for http using ${HTTP_HOSTNAME} ..." $cyan
		keytool -keystore certificates.ks -storetype JCEKS -storepass ${KEYSTORE_PASSWORD} -keypass ${KEYSTORE_PASSWORD} -genkey -keyalg RSA -alias http -dname "CN=${HTTP_HOSTNAME}, OU=${KEYSTORE_ORG_UNIT_NAME}, O=${KEYSTORE_ORG}, L=${KEYSTORE_CITY},S=${KEYSTORE_STATE}, C=${KEYSTORE_COUNTRY}"
		keytool -keystore certificates.ks -storetype JCEKS -storepass ${KEYSTORE_PASSWORD} -keypass ${KEYSTORE_PASSWORD} -certreq -alias http -file http.csr
	
		cecho "Creating keystore certificate for consoleproxy using ${CONSOLEPROXY_HOSTNAME} ..." $cyan
		keytool -keystore certificates.ks -storetype JCEKS -storepass ${KEYSTORE_PASSWORD} -keypass ${KEYSTORE_PASSWORD} -genkey -keyalg RSA -alias consoleproxy -dname "CN=${HTTP_HOSTNAME}, OU=${KEYSTORE_ORG_UNIT_NAME}, O=${KEYSTORE_ORG}, L=${KEYSTORE_CITY},S=${KEYSTORE_STATE}, C=${KEYSTORE_COUNTRY}" 
		keytool -keystore certificates.ks -storetype JCEKS -storepass ${KEYSTORE_PASSWORD} -keypass ${KEYSTORE_PASSWORD} -certreq -alias consoleproxy -file consoleproxy.csr

		cecho "Moving certificates.ks to /opt/keystore ..." $cyan
		if [ -f certificates.ks ]; then
			mkdir -p /opt/keystore
			mv certificates.ks /opt/keystore
		else 
			cecho "Error! Unable to locate certificates.ks in current working directory, certificates may not have been generated correctly!" $red
		fi
	else 
		cecho "Looks like /opt/keystore/certificates.ks exists already! Will not generated vCD keystores!" $red
	fi
}

installvCD() {
	VCD_INSTALL_RESPONSE_FILE=/tmp/vcd-install-$$.response

	rpm -qa | grep -i "vmware-cloud-director" > /dev/null 2>&1
	if [ $? -eq 1 ]; then
		cecho "Install vCloud Director Binary: ${VMWARE_VCD_BIN} ..." $cyan
		cat > ${VCD_INSTALL_RESPONSE_FILE} << __VCD_INSTALL__
y
n
__VCD_INSTALL__

		chmod u+x ${VMWARE_VCD_BIN}
		./${VMWARE_VCD_BIN} < ${VCD_INSTALL_RESPONSE_FILE}

		rm -f ${VCD_INSTALL_RESPONSE_FILE}
	else
		cecho "vCloud Director Binary is already installed!" $red
	fi
	
	if [ ${ENABLE_NESTED_ESX} == "true" ]; then
		sed -i '/extension.esxvm.enabled/s/false/true/' /opt/vmware/vcloud-director/db/oracle/NewInstall_Data.sql
		sed -i '/extension.esxvm.enabled/s/false/true/' /opt/vmware/vcloud-director/db/mssql/NewInstall_Data.sql
	fi
	}

configurevCD() {
	VCD_CONFIG_RESPONSE_FILE=/tmp/vcd-configure-$$.response
	if [[ ${VCLOUD_VERSION} == "1.0" ]] || [[ ${VCLOUD_VERSION} == "1.0.1" ]]; then
		VCD_PATH=/opt/vmware/cloud-director
	elif [[ ${VCLOUD_VERSION} == "1.5" ]] || [[ ${VCLOUD_VERSION} == "5.1" ]]; then
		VCD_PATH=/opt/vmware/vcloud-director
	fi
	
	cecho "Creating vCloud Director Configuration Response File for vCD ${VCLOUD_VERSION}: ${VCD_CONFIG_RESPONSE_FILE} ..." $cyan
	if [[ ${VCLOUD_VERSION} == "1.0" ]] || [[ ${VCLOUD_VERSION} == "1.0.1" ]]; then
		cat > ${VCD_CONFIG_RESPONSE_FILE} << __VCD_CONFIGURE__
1
1
/opt/keystore/certificates.ks
${KEYSTORE_PASSWORD}

127.0.0.1

xe
${ORACLE_VCLOUD_USERNAME}
${ORACLE_VCLOUD_PASSWORD}
__VCD_CONFIGURE__
	elif [[ ${VCLOUD_VERSION} == "1.5" ]] || [[ ${VCLOUD_VERSION} == "5.1" ]]; then
		cat > ${VCD_CONFIG_RESPONSE_FILE} << __VCD_CONFIGURE__
1
1
/opt/keystore/certificates.ks
${KEYSTORE_PASSWORD}

1
127.0.0.1

xe
${ORACLE_VCLOUD_USERNAME}
${ORACLE_VCLOUD_PASSWORD}
__VCD_CONFIGURE__
	fi
	
	cecho "Configuring vCloud Director and using Configuration Response File: ${VCD_CONFIG_RESPONSE_FILE} ..." $cyan
	${VCD_PATH}/bin/configure < ${VCD_CONFIG_RESPONSE_FILE}

	cecho "Removing vCloud Director Configuration Reponse file: ${VCD_CONFIG_RESPONSE_FILE} ...." $cyan
	rm -f ${VCD_CONFIG_RESPONSE_FILE}

	cecho "Completed installation of vCloud Director!" $cyan
	cecho "Starting vCloud Director ..." $cyan
	${VCD_PATH}/bin/vmware-vcd start
	cecho "Waiting for vCloud Director to finish intialization ..." $cyan
	VCD_START_SUCCESS=0
	VCD_START_COUNT=0
	VCD_START_MAX_COUNT=12
	while [ 1 ];
	do
        	grep -i "Application Initialization: Complete" ${VCD_PATH}/logs/vcloud-container-info.log > /dev/null 2>&1
	        if [ $? -eq 0 ]; then
			cecho "vCloud Director is up and running! You can now go to https://${HTTP_HOSTNAME}" $cyan
        	        break
	        else
			if [ ${VCD_START_COUNT} = ${VCD_START_MAX_COUNT} ]; then
				cecho "Unable to start vCloud Director, something went wrong! =[ - Please take a look at ${VCD_PATH}/logs/vcloud-container-info.log for more info" $red
				break
			fi
			VCD_START_COUNT=$((VCD_START_COUNT+1))
                	sleep 5
        	fi
	done
}

enableESXVM() {
	cecho "************************** THIS IS NOT A SUPPORTED CONFIGURATION **************************" $notsupported
        echo

        ESXVM_SCRIPT=/tmp/esxvm-$$.sh
        if [ ${ORACLE_VERSION} == "10.2.0" ]; then
                ORACLE_HOME=/usr/lib/oracle/xe/app/oracle/product/${ORACLE_VERSION}/server
        elif [ ${ORACLE_VERSION} == "11.2.0" ]; then
                ORACLE_HOME=/u01/app/oracle/product/${ORACLE_VERSION}/xe
        fi
        ORACLE_SID=XE
	
	if [[ ${VCLOUD_VERSION} == "1.0" ]] || [[ ${VCLOUD_VERSION} == "1.0.1" ]]; then
                VCD_PATH=/opt/vmware/cloud-director
        elif [[ ${VCLOUD_VERSION} == "1.5" ]] || [[ ${VCLOUD_VERSION} == "5.1" ]]; then
                VCD_PATH=/opt/vmware/vcloud-director
        fi
	HTTP_IP=$(grep IPADDR /etc/sysconfig/network-scripts/ifcfg-eth0 | awk -F "=" '{print $2}')
        HTTP_HOSTNAME=$(host ${HTTP_IP} | awk '{print $5}' | sed 's/.$//g')

        cecho "Executing ESXVM SQL ..." $cyan
        export ORACLE_HOME=${ORACLE_HOME}
        export ORACLE_SID=XE
        export PATH=$PATH:$ORACLE_HOME/bin

        sqlplus "${ORACLE_VCLOUD_USERNAME}/${ORACLE_VCLOUD_PASSWORD}" << EOF
INSERT INTO guest_osfamily (family,family_id) VALUES ('VMware ESX/ESXi',6);

INSERT INTO guest_os_type (guestos_id,display_name, internal_name, family_id, is_supported, is_64bit, min_disk_gb, min_memory_mb, min_hw_version, supports_cpu_hotadd, supports_mem_hotadd, diskadapter_id, max_cpu_supported, is_personalization_enabled, is_personalization_auto, is_sysprep_supported, is_sysprep_os_packaged, cim_id, cim_version) VALUES (seq_config.NextVal,'ESXi 4.x', 'vmkernelGuest', 6, 1, 1, 8, 3072, 7,1, 1, 4, 8, 0, 0, 0, 0, 107, 40);

INSERT INTO guest_os_type (guestos_id,display_name, internal_name, family_id, is_supported, is_64bit, min_disk_gb, min_memory_mb, min_hw_version, supports_cpu_hotadd, supports_mem_hotadd, diskadapter_id, max_cpu_supported, is_personalization_enabled, is_personalization_auto, is_sysprep_supported, is_sysprep_os_packaged, cim_id, cim_version) VALUES (seq_config.NextVal, 'ESXi 5.x', 'vmkernel5Guest', 6, 1, 1, 8, 3072, 7,1, 1, 4, 8, 0, 0, 0, 0, 107, 50);

UPDATE Config SET value='true' WHERE name='extension.esxvm.enabled';
EOF
        sleep 10

	cecho "Restarting vCloud Director Cell ..." $cyan
        ${VCD_PATH}/bin/vmware-vcd restart
        cecho "Waiting for vCloud Director to finish intialization ..." $cyan
        VCD_START_SUCCESS=0
        VCD_START_COUNT=0
        VCD_START_MAX_COUNT=24
        while [ 1 ];
        do
                grep -i "Application Initialization: Complete" ${VCD_PATH}/logs/vcloud-container-info.log > /dev/null 2>&1
                if [ $? -eq 0 ]; then
                        cecho "vCloud Director is up and running! You can now go to https://${HTTP_HOSTNAME}" $cyan
                        break
                else
                        if [ ${VCD_START_COUNT} = ${VCD_START_MAX_COUNT} ]; then
                                cecho "Unable to start vCloud Director, something went wrong! =[ - Please take a look at ${VCD_PATH}/logs/vcloud-container-info.log for more info" $red
                                break
                        fi
                        VCD_START_COUNT=$((VCD_START_COUNT+1))
                        sleep 10
                fi
        done
	cecho "************************** THIS IS NOT A SUPPORTED CONFIGURATION **************************" $notsupported
	echo 
}

############## START INSTALLER ##############

if [ $# -ne 1 ]; then
	usage
else 
	source ${1}
	verify
	configureYUM
	installPreReqs
	disableServices
	installOracle
	configureOracle
	createSecondInterface
	generateCertificates
	installvCD
	configurevCD
	if [ ${ENABLE_NESTED_ESX} == "true" ]; then
		enableESXVM
	fi
fi

