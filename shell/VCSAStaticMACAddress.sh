#!/bin/bash
# William Lam
# www.williamlam.com

OVFTOOL_BIN_PATH="/Applications/VMware OVF Tool/ovftool"
#VCSA_OVA="/Volumes/Storage/Software/VMware-VCSA-all-6.7.0-Update-3b-15132721/vcsa/VMware-vCenter-Server-Appliance-6.7.0.42000-15132721_OVF10.ova"
VCSA_OVA="/Volumes/Storage/Software/VMware-VCSA-all-6.7.0-Update-3b-15132721/vcsa/VMware-vCenter-Server-Appliance-6.7.0.42000-15132721_OVF10.ovf"

# vCenter
#DEPLOYMENT_TARGET_ADDRESS=192.168.30.200
#DEPLOYMENT_TARGET_USERNAME="administrator@vsphere.local"
#DEPLOYMENT_TARGET_PASSWORD="VMware1!"
#DEPLOYMENT_TARGET_DATACENTER="Primp-Datacenter" # leave blank for ESXi only
#DEPLOYMNET_TARGET_CLUSTER="Supermicro-Cluster" # leave blank for ESXi only

#ESXi
DEPLOYMENT_TARGET_ADDRESS=192.168.30.14
DEPLOYMENT_TARGET_USERNAME="root"
DEPLOYMENT_TARGET_PASSWORD="VMware1!"

VCSA_NAME="VCSA-STATIC-MAC"
VCSA_SIZE="tiny"
VCSA_IP="192.168.30.190"
VCSA_HOSTNAME="192.168.30.190"
VCSA_GW="192.168.30.1"
VCSA_CIDR="24"
VCSA_DNS="192.168.30.1"
VCSA_NTP="pool.ntp.org"
VCSA_SSO_DOMAIN="vsphere.local"
VCSA_SSO_PASSWORD="VMware1!"
VCSA_PASSWORD="VMware1!"
VCSA_NETWORK="VM Network"
VCSA_DATASTORE="sm-vsanDatastore"
VCSA_STAGE1ANDSTAGE2="True"

### DO NOT EDIT BEYOND HERE ###

if [[ ! -z ${DEPLOYMENT_TARGET_DATACENTER} && ! -z ${DEPLOYMNET_TARGET_CLUSTER} ]]; then
    echo "Deploying VCSA to a Center Server deployment target ..."
    "${OVFTOOL_BIN_PATH}" \
        --acceptAllEulas \
        --X:enableHiddenProperties \
        --noSSLVerify \
        --sourceType=OVA \
        --allowExtraConfig \
        --diskMode=thin \
        --name="${VCSA_NAME}" \
        --net:"Network 1"="${VCSA_NETWORK}" \
        --datastore="${VCSA_DATASTORE}" \
        --deploymentOption=${VCSA_SIZE} \
        --prop:guestinfo.cis.deployment.node.type=embedded \
        --prop:guestinfo.cis.appliance.net.addr=${VCSA_IP} \
        --prop:guestinfo.cis.appliance.net.pnid=${VCSA_HOSTNAME} \
        --prop:guestinfo.cis.appliance.net.mode=static \
        --prop:guestinfo.cis.appliance.net.addr.family=ipv4 \
        --prop:guestinfo.cis.appliance.net.prefix=${VCSA_CIDR} \
        --prop:guestinfo.cis.appliance.net.gateway=${VCSA_GW} \
        --prop:guestinfo.cis.appliance.ntp.servers=${VCSA_NTP} \
        --prop:guestinfo.cis.appliance.net.dns.servers=${VCSA_DNS} \
        --prop:guestinfo.cis.vmdir.domain-name=${VCSA_SSO_DOMAIN} \
        --prop:guestinfo.cis.vmdir.password=${VCSA_SSO_PASSWORD} \
        --prop:guestinfo.cis.appliance.root.passwd=${VCSA_PASSWORD} \
        --prop:guestinfo.cis.system.vm0.port=443 \
        --prop:guestinfo.cis.appliance.ssh.enabled=True \
        --prop:guestinfo.cis.ceip_enabled=True \
        --prop:guestinfo.cis.vmdir.first-instance=True \
        --prop:guestinfo.cis.deployment.autoconfig=${VCSA_STAGE1ANDSTAGE2} \
        "${VCSA_OVA}" \
        "vi://${DEPLOYMENT_TARGET_USERNAME}:${DEPLOYMENT_TARGET_PASSWORD}@${DEPLOYMENT_TARGET_ADDRESS}/${DEPLOYMENT_TARGET_DATACENTER}/host/${DEPLOYMNET_TARGET_CLUSTER}"
else
    echo "Deploying VCSA to a ESXi deployment target ..."
    "${OVFTOOL_BIN_PATH}" \
        --powerOn \
        --X:injectOvfEnv \
        --acceptAllEulas \
        --noSSLVerify \
        --sourceType=OVF \
        --allowExtraConfig \
        --diskMode=thin \
        --name="${VCSA_NAME}" \
        --net:"Network 1"="${VCSA_NETWORK}" \
        --datastore="${VCSA_DATASTORE}" \
        --deploymentOption=${VCSA_SIZE} \
        --prop:guestinfo.cis.deployment.node.type=embedded \
        --prop:guestinfo.cis.appliance.net.addr=${VCSA_IP} \
        --prop:guestinfo.cis.appliance.net.pnid=${VCSA_HOSTNAME} \
        --prop:guestinfo.cis.appliance.net.mode=static \
        --prop:guestinfo.cis.appliance.net.addr.family=ipv4 \
        --prop:guestinfo.cis.appliance.net.prefix=${VCSA_CIDR} \
        --prop:guestinfo.cis.appliance.net.gateway=${VCSA_GW} \
        --prop:guestinfo.cis.appliance.ntp.servers=${VCSA_NTP} \
        --prop:guestinfo.cis.appliance.net.dns.servers=${VCSA_DNS} \
        --prop:guestinfo.cis.vmdir.domain-name=${VCSA_SSO_DOMAIN} \
        --prop:guestinfo.cis.vmdir.password=${VCSA_SSO_PASSWORD} \
        --prop:guestinfo.cis.appliance.root.passwd=${VCSA_PASSWORD} \
        --prop:guestinfo.cis.system.vm0.port=443 \
        --prop:guestinfo.cis.appliance.ssh.enabled=True \
        --prop:guestinfo.cis.ceip_enabled=True \
        --prop:guestinfo.cis.vmdir.first-instance=True \
        --prop:guestinfo.cis.deployment.autoconfig=${VCSA_STAGE1ANDSTAGE2} \
        "${VCSA_OVA}" \
        "vi://${DEPLOYMENT_TARGET_USERNAME}:${DEPLOYMENT_TARGET_PASSWORD}@${DEPLOYMENT_TARGET_ADDRESS}/"
fi
