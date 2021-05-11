#!/bin/bash
# Author: William Lam
# Site: www.williamlam.com
# Reference: http://www.williamlam.com/2015/01/ultimate-automation-guide-to-deploying-vcsa-6-0-part-4-vcenter-server-management-node.html

OVFTOOL="/Volumes/Storage/Images/Beta/VMware-VCSA-all-6.0.0-2497477/vcsa-cli-installer/mac/VMware OVF Tool/ovftool"
VCSA_OVA=/Volumes/Storage/Images/Beta/VMware-VCSA-all-6.0.0-2497477/vcsa/vmware-vcsa

VCENTER_SERVER=192.168.1.60
VCENTER_USERNAME=administrator@vghetto.local
VCENTER_PASSWORD=VMware1!
ESXI_HOST=mini.primp-industries.com
VM_NETWORK="VM Network"
VM_DATASTORE=mini-local-datastore-2

# Configurations for VC Management Node
VCSA_VMNAME=vcsa-01
VCSA_ROOT_PASSWORD=VMware1!
VCSA_NETWORK_MODE=static
VCSA_NETWORK_FAMILY=ipv4
## IP Network Prefix (CIDR notation)
VCSA_NETWORK_PREFIX=24
## Same value as VCSA_IP if no DNS
VCSA_HOSTNAME=192.168.1.52
VCSA_IP=192.168.1.52
VCSA_GATEWAY=192.168.1.1
VCSA_DNS=192.168.1.1
VCSA_ENABLE_SSH=True
VCSA_DEPLOYMENT_SIZE=management-tiny
FIRST_PSC_NODE=192.168.1.50

# Configuration for SSO
SSO_DOMAIN_NAME=vghetto.local
SSO_SITE_NAME=vghetto
SSO_ADMIN_PASSWORD=VMware1!

# NTP Servers
NTP_SERVERS=0.pool.ntp.org

### DO NOT EDIT BEYOND HERE ###

"${OVFTOOL}" --version | grep '4.1.0' > /dev/null 2>&1
if [ $? -eq 1 ]; then
	echo "This script requires ovftool 4.1.0 ..."
	exit 1
fi

echo -e "\nDeploying vCenter Server Appliance Management Node ${VCSA_VMNAME} ..."
"${OVFTOOL}" --acceptAllEulas --skipManifestCheck --X:injectOvfEnv --allowExtraConfig --X:enableHiddenProperties --X:waitForIp --sourceType=OVA --powerOn \
"--net:Network 1=${VM_NETWORK}" --datastore=${VM_DATASTORE} --diskMode=thin --name=${VCSA_VMNAME} \
"--deploymentOption=${VCSA_DEPLOYMENT_SIZE}" \
"--prop:guestinfo.cis.system.vm0.hostname=${FIRST_PSC_NODE}" \
"--prop:guestinfo.cis.vmdir.domain-name=${SSO_DOMAIN_NAME}" \
"--prop:guestinfo.cis.vmdir.site-name=${SSO_SITE_NAME}" \
"--prop:guestinfo.cis.vmdir.password=${SSO_ADMIN_PASSWORD}" \
"--prop:guestinfo.cis.appliance.net.addr.family=${VCSA_NETWORK_FAMILY}" \
"--prop:guestinfo.cis.appliance.net.addr=${VCSA_IP}" \
"--prop:guestinfo.cis.appliance.net.pnid=${VCSA_HOSTNAME}" \
"--prop:guestinfo.cis.appliance.net.prefix=${VCSA_NETWORK_PREFIX}" \
"--prop:guestinfo.cis.appliance.net.mode=${VCSA_NETWORK_MODE}" \
"--prop:guestinfo.cis.appliance.net.dns.servers=${VCSA_DNS}" \
"--prop:guestinfo.cis.appliance.net.gateway=${VCSA_GATEWAY}" \
"--prop:guestinfo.cis.appliance.root.passwd=${VCSA_ROOT_PASSWORD}" \
"--prop:guestinfo.cis.appliance.ssh.enabled=${VCSA_ENABLE_SSH}" \
"--prop:guestinfo.cis.appliance.ntp.servers=${NTP_SERVERS}" \
${VCSA_OVA} "vi://${VCENTER_USERNAME}:${VCENTER_PASSWORD}@${VCENTER_SERVER}/?dns=${ESXI_HOST}"

echo "Checking to see if the VCSA endpoint https://${VCSA_IP}/ is ready ..."
until [[ $(curl --connect-timeout 30 -s -o /dev/null -w "%{http_code}" -i -k https://${VCSA_IP}/) -eq 200 ]];
do
	echo "Not ready, sleeping for 60sec"
	sleep 60
done
echo "VCSA Management Node (${VCSA_IP}) is now ready!"
