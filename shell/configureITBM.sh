#!/bin/bash
# Author: William Lam
# Website: www.virtuallyghetto.com
# Product: VMware IT Business Management
# Description: Script to automate the configuration of ITBM VA
# Reference: http://www.virtuallyghetto.com/2014/01/automating-vmware-itbm-it-business.html

VCAC_VA_SERVER=vcac-va.primp-industries.com
VCAC_SSO_PASSWORD=vmware
TIMEZONE=UTC

### DO NOT EDIT BEYOND HERE ###

echo "Configuring Timezone to ${TIMEZONE} ..."
/opt/vmware/share/vami/vami_set_timezone_cmd "${TIMEZONE}"

echo "Registering ITBM VA with vCAC Server ${VCAC_VA_SERVER} ..."
/usr/sbin/itfm-config /usr/local/tcserver/vfabric-tc-server-standard/tcinstance1 "${VCAC_VA_SERVER}" vsphere.local administrator "${VCAC_SSO_PASSWORD}"
