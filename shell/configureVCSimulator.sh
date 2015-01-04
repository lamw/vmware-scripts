#!/bin/bash
# Author: William Lam
# Website: www.virtuallyghetto.com
# Product: VMware vCloud Director
# Description: Setting up VCD Simulator 
# Reference: http://www.virtuallyghetto.com/2013/01/vcloud-director-simulator.html

ESXI_MAJOR_VERSION=5.1
ESXI_FULL_VERSION=5.1.0
ESXI_BUILD=123456

### DO NOT MODIFY BEYOND HERE ###

VPXD_CONF=/etc/vmware-vpx/vpxd.cfg
HOST_CONFIG_INFO=/etc/vmware-vpx/vcsim/model/HostConfigInfo.xml
HOST_LIST_SUMMARY=/etc/vmware-vpx/vcsim/model/HostListSummary.xml
HOST_RUNTIME_INFO=/etc/vmware-vpx/vcsim/model/HostRuntimeInfo.xml
LICENSE_MANAGER_INFO=/etc/vmware-vpx/vcsim/model/LicenseManagerLicenseInfo.xml

echo "Backing up original XML configuration files ..."
cp ${VPXD_CONF} ${VPXD_CONF}.bak
cp ${HOST_CONFIG_INFO} ${HOST_CONFIG_INFO}.bak
cp ${HOST_LIST_SUMMARY} ${HOST_LIST_SUMMARY}.bak
cp ${HOST_RUNTIME_INFO} ${HOST_RUNTIME_INFO}.bak
cp ${LICENSE_MANAGER_INFO} ${LICENSE_MANAGER_INFO}.bak

grep simulator ${VPXD_CONF} > /dev/null 2>&1
if [ $? -eq 1 ];then 
	echo "Updating ${VPXD_CONF}"
sed -i 's/<\/vpxd>/<\/vpxd>\
   <simulator>\
     <enabled>true<\/enabled>\
     <cleardb>false<\/cleardb>\
     <initInventory>vcsim\/model\/initInventory.cfg<\/initInventory>\
     <metricMetadata>vcsim\/model\/metricMetadata.cfg<\/metricMetadata>\
     <vcModules>vcsim\/model\/vcModules.cfg<\/vcModules>\
     <vcDelay>vcsim\/model\/OperationDelay.cfg<\/vcDelay>\
   <\/simulator>/g' /etc/vmware-vpx/vpxd.cfg
else
	echo "${VPXD_CONF} looks like it already has the simulator configurations"
fi

echo "Updating ${HOST_CONFIG_INFO}"
sed -i "s/<fullName>.*/<fullName>VMware ESX ${ESXI_FULL_VERSION} build-${ESXI_BUILD}<\/fullName>/g" ${HOST_CONFIG_INFO}
sed -i "s/<build>.*/<build>${ESXI_BUILD}<\/build>/g" ${HOST_CONFIG_INFO}
sed -i "s/<apiVersion>.*/<apiVersion>${ESXI_MAJOR_VERSION}<\/apiVersion>/g" ${HOST_CONFIG_INFO}
sed -i "s/<licenseProductVersion>.*/<licenseProductVersion>${ESXI_MAJOR_VERSION}<\/licenseProductVersion>/g" ${HOST_CONFIG_INFO}
sed -i "s/<version>.*/<version>${ESXI_FULL_VERSION}<\/version>/g" ${HOST_CONFIG_INFO}
sed -i 's/ESXi/ESX/g' ${HOST_CONFIG_INFO}
sed -i 's/<productLineId>.*/<productLineId>esx<\/productLineId>/g' ${HOST_CONFIG_INFO}

echo "Updating ${HOST_LIST_SUMMARY}"
sed -i "s/<fullName>.*/<fullName>VMware ESX ${ESXI_FULL_VERSION} build-${ESXI_BUILD}<\/fullName>/g" ${HOST_LIST_SUMMARY}
sed -i "s/<build>.*/<build>${ESXI_BUILD}<\/build>/g" ${HOST_LIST_SUMMARY}
sed -i "s/<apiVersion>.*/<apiVersion>${ESXI_MAJOR_VERSION}<\/apiVersion>/g" ${HOST_LIST_SUMMARY}
sed -i "s/<licenseProductVersion>.*/<licenseProductVersion>${ESXI_MAJOR_VERSION}<\/licenseProductVersion>/g" ${HOST_LIST_SUMMARY}
sed -i "s/<version>.*/<version>${ESXI_FULL_VERSION}<\/version>/g" ${HOST_LIST_SUMMARY}
sed -i 's/ESXi/ESX/g' ${HOST_LIST_SUMMARY}
sed -i 's/<productLineId>.*/<productLineId>esx<\/productLineId>/g' ${HOST_LIST_SUMMARY}

echo "Updating ${HOST_RUNTIME_INFO}"
sed -i "s/<fullName>.*/<fullName>VMware ESX ${ESXI_FULL_VERSION} build-${ESXI_BUILD}<\/fullName>/g" ${HOST_RUNTIME_INFO}
sed -i 's/ESXi/ESX/g' ${HOST_RUNTIME_INFO}

echo "Updating ${LICENSE_MANAGER_INFO}"
sed -i "s/<value xsi:type=""xsd:string\">[1-9].[0-9].*/<value xsi:type=\"xsd:string\">${ESXI_MAJOR_VERSION}<\/value>/g" ${LICENSE_MANAGER_INFO}
