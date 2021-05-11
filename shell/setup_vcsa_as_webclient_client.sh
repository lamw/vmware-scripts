#!/bin/bash
# Author: William Lam
# Site: www.williamlam.com
# Reference: http://www.williamlam.com/2015/04/configuring-vcsa-6-0-as-vsphere-web-client-server-for-vsphere-5-5.html 

# External SSO Server
PSC_SERVER=sso.primp-industries.com

# SSO Username
SSO_USERNAME=administrator@vsphere.local

# SSO Password
SSO_PASSWORD=VMware1!

### DO NOT EDIT BEYOND HERE ###

echo "Extracting vCenter Server Service ID ..."
VC_SERVICE_ID=$(grep cmreg.serviceid $(grep vcenterserver /etc/vmware/rereg/* | awk -F ':' '{print $1}') | awk -F 'cmreg.serviceid=' '{print $2}')

echo "Unregistering vCenter Server using ID: ${VC_SERVICE_ID} ..."
/usr/lib/vmidentity/tools/scripts/lstool.py unregister --url https://${PSC_SERVER}/lookupservice/sdk --id ${VC_SERVICE_ID} --user "${SSO_USERNAME}" --password "${SSO_PASSWORD}" --no-check-cert

# Stopping all services to make bootup changes
/bin/service-control --stop --all --ignore

# List of non-required services for running vSphere Web Client
DISABLE_SERVICES=(
applmgmt
vmware-cis-license
vmware-eam
vmware-mbcs
vmware-netdumper
vmware-perfcharts
vmware-rbd-watchdog
vmware-sca
vmware-sps
vmware-syslog
vmware-syslog-health
vmware-vapi-endpoint
vmware-vdcs
vmware-vpx-workflow
vmware-vpxd
vmware-vsm
vmware-vws
)

for SERVICE in ${DISABLE_SERVICES[@]}
do
        echo "Disabling ${SERVICE} and changing memory size to 0 MB ..."
        chkconfig --force ${SERVICE} off
        cloudvm-ram-size -C 0 ${SERVICE}
done

echo "Please shutdown the VCSA and modify its memory configuration to 3GB or as approrpiate ...""
