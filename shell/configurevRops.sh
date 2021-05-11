#!/bin/bash
# Author: William Lam
# Website: www.williamlam.com
# Product: VMware vRealize Operations Manager 6.0
# Description: Automating Configuration of vRealize Operations Manager 6.0 via CLI
# Reference: http://www.williamlam.com/2014/12/automating-deployment-configuration-of-vrealize-operations-manager-6-0-part-2.html

VROPS_ADMIN_PASSWORD='VMware1!'

# NTP Servers must be reachable, else set to 0 for false, 1 for true
CONFIGURE_NTP=0
NTP_SERVERS="0.pool.ntp.org 1.pool.ntp.org"

### DO NOT EDIT BEYOND HERE ###

# http://stackoverflow.com/a/24884959
NTP_STRING=$(echo ${NTP_SERVERS} | awk -v RS='' -v OFS='","' 'NF { $1 = $1; print "\"" $0 "\"" }')

if [ ${CONFIGURE_NTP} -eq 1 ]; then
	echo "Configuring NTP Servers ..."
	echo "[${NTP_STRING}]" | /usr/lib/vmware-casa/bin/ntp_update.py > /dev/null 2>&1
fi

echo "Configuring vROps Admin password ..."
/usr/lib/vmware-vcopssuite/utilities/sliceConfiguration/bin/vcopsSetAdminPassword.py "${VROPS_ADMIN_PASSWORD}" > /dev/null 2>&1

echo "Configuring vROps Cluster Role & Slice Configurations ..."
echo "${VROPS_ADMIN_PASSWORD}" | /usr/lib/vmware-vcopssuite/utilities/sliceConfiguration/bin/vcopsConfigureRoles.py --all=true --enrollUser=admin > /dev/null 2>&1

echo "Initializing vROps Cluster ..."
/usr/lib/vmware-vcopssuite/utilities/sliceConfiguration/bin/vcopsClusterManager.py init-cluster > /dev/null 2>&1
