#!/bin/bash
# Author: William Lam
# Site: www.williamlam.com
# Reference: http://www.williamlam.com/2015/01/ultimate-automation-guide-to-deploying-vcsa-6-0-part-3-replicated-platform-service-controller-node.html

OVFTOOL="/Applications/VMware OVF Tool/ovftool"
VCSA_OVA=/Volumes/Storage/Images/Beta/VMware-VCSA-all-6.0.0-2497477/vcsa/vmware-vcsa

ESXI_HOST=192.168.1.200
ESXI_USERNAME=root
ESXI_PASSWORD=vmware123
VM_NETWORK="VM Network"
VM_DATASTORE=mini-local-datastore-2

# Configurations for Replication PSC Node
FIRST_PSC_NODE=192.168.1.50
PSC_REPLICATION_VMNAME=psc-02
PSC_REPLICATION_ROOT_PASSWORD=VMware1!
PSC_REPLICATION_NETWORK_MODE=static
PSC_REPLICATION_NETWORK_FAMILY=ipv4
## IP Network Prefix (CIDR notation)
PSC_REPLICATION_NETWORK_PREFIX=24
## Same value as VCSA_IP if no DNS
PSC_REPLICATION_HOSTNAME=192.168.1.51
PSC_REPLICATION_IP=192.168.1.51
PSC_REPLICATION_GATEWAY=192.168.1.1
PSC_REPLICATION_DNS=192.1681.1
PSC_REPLICATION_ENABLE_SSH=True

# Configuration for SSO
SSO_DOMAIN_NAME=vghetto.local
SSO_SITE_NAME=vghetto
SSO_ADMIN_PASSWORD=VMware1!

# NTP Servers
NTP_SERVERS=0.pool.ntp.org

### DO NOT EDIT BEYOND HERE ###

"${OVFTOOL}" --version | grep '4.0.0' > /dev/null 2>&1
if [ $? -eq 1 ]; then
	echo "This script requires ovftool 4.0.0 ..."
	exit 1
fi

echo -e "\nDeploying Replicated Platform Service Controller Node ${PSC_REPLICATION_VMNAME} connected to ${FIRST_PSC_NODE} ..."
"${OVFTOOL}" --acceptAllEulas --skipManifestCheck --X:injectOvfEnv --allowExtraConfig --X:enableHiddenProperties --X:waitForIp --sourceType=OVA --powerOn \
"--net:Network 1=${VM_NETWORK}" --datastore=${VM_DATASTORE} --diskMode=thin --name=${PSC_REPLICATION_VMNAME} \
"--deploymentOption=infrastructure" \
"--prop:guestinfo.cis.vmdir.domain-name=${SSO_DOMAIN_NAME}" \
"--prop:guestinfo.cis.vmdir.site-name=${SSO_SITE_NAME}" \
"--prop:guestinfo.cis.vmdir.password=${SSO_ADMIN_PASSWORD}" \
"--prop:guestinfo.cis.vmdir.first-instance=False" \
"--prop:guestinfo.cis.vmdir.replication-partner-hostname=${FIRST_PSC_NODE}" \
"--prop:guestinfo.cis.appliance.net.addr.family=${PSC_REPLICATION_NETWORK_FAMILY}" \
"--prop:guestinfo.cis.appliance.net.addr=${PSC_REPLICATION_IP}" \
"--prop:guestinfo.cis.appliance.net.pnid=${PSC_REPLICATION_HOSTNAME}" \
"--prop:guestinfo.cis.appliance.net.prefix=${PSC_REPLICATION_NETWORK_PREFIX}" \
"--prop:guestinfo.cis.appliance.net.mode=${PSC_REPLICATION_NETWORK_MODE}" \
"--prop:guestinfo.cis.appliance.net.dns.servers=${PSC_REPLICATION_DNS}" \
"--prop:guestinfo.cis.appliance.net.gateway=${PSC_REPLICATION_GATEWAY}" \
"--prop:guestinfo.cis.appliance.root.passwd=${PSC_REPLICATION_ROOT_PASSWORD}" \
"--prop:guestinfo.cis.appliance.ssh.enabled=${PSC_REPLICATION_ENABLE_SSH}" \
"--prop:guestinfo.cis.appliance.ntp.servers=${NTP_SERVERS}" \
${VCSA_OVA} "vi://${ESXI_USERNAME}:${ESXI_PASSWORD}@${ESXI_HOST}/"

echo "Checking to see if the PSC Replication endpoint https://${PSC_REPLICATION_IP}/websso/ is ready ..."
until [[ $(curl --connect-timeout 30 -s -o /dev/null -w "%{http_code}" -i -k https://${PSC_REPLICATION_IP}/websso/) -eq 200 ]];
do
	echo "Not ready, sleeping for 60sec"
	sleep 60
done
echo "VCSA Replicated Platform Service Controller Node (${PSC_REPLICATION_IP}) is now ready!"
