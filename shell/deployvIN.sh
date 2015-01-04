#!/bin/bash
# Author: William Lam
# Website: www.virtuallyghetto.com
# Product: VMware vCenter Infrastructure Navigator
# Description: Wrapper script to deploy VMware vIN Virtual Apppliance
# Reference: http://www.virtuallyghetto.com/2012/02/unattended-deployment-of-vcenter.html

# Configurations 

# vIN OVF
VIN_OVA=Navigator-1.0.0.49-592384_OVF10.ova

# e.g. 172.30.0.141/24 
VIN_DISPLAY_NAME=vin
VIN_HOSTNAME=vin.primp-industries.com
VIN_PORTGROUP=VM_Network
VIN_DATASTORE=iSCSI-4
VIN_DISK_TYPE=thin
VIN_IPADDRESS=172.30.0.150
VIN_NETMASK=255.255.255.0
VIN_GATEWAY=172.30.0.1
VIN_DNS=172.30.0.100
VIN_IPPROTOCOL=IPv4
VIN_PASSWORD=vmware123

# vCenter or ESX(i)
VCENTER_HOSTNAME=vcenter50-4.primp-industries.com
VCENTER_USERNAME=root
VCENTER_PASSWORD=vmware
ESXI_HOSTNAME=vesxi50-3.primp-industries.com

############## DO NOT EDIT BEYOND HERE #################

cyan='\E[36;40m'
green='\E[32;40m'
red='\E[31;40m'
yellow='\E[33;40m'

cecho() {
        local default_msg="No message passed."
        message=${1:-$default_msg}
        color=${2:-$green}
        echo -e "$color"
        echo -e "$message"
        tput sgr0

        return
}

verify() {
	if [ ! -e ${VIN_OVA} ]; then
		cecho "Unable to locate \"${VIN_OVA}\"!" $red
		exit 1
	fi

	cecho "Would you like to deploy the following configuration for vCenter Infrastructure Navigator?" $yellow
	cecho "\tVMware vCenter Infrastructure Navigator Virtual Appliance: ${VIN_OVA}" $green
	cecho "\tvIN Display Name: ${VIN_DISPLAY_NAME}" $green
	cecho "\tvIN Hostname: ${VIN_HOSTNAME}" $green
	cecho "\tvIN IP Address: ${VIN_IPADDRESS}" $green
	cecho "\tvIN Netmask: ${VIN_NETMASK}" $green
	cecho "\tvIN Gateway: ${VIN_GATEWAY}" $green
	cecho "\tvIN DNS: ${VIN_DNS}" $green
	cecho "\tvIN IP Protocol: ${VIN_IPPROTOCOL}" $green
	cecho "\tvIN Portgroup: ${VIN_PORTGROUP}" $green
	cecho "\tvIN Datastore: ${VIN_DATASTORE}" $green
	cecho "\tvIN Disk Type: ${VIN_DISK_TYPE}" $green
	cecho "\tvCenter Server: ${VCENTER_HOSTNAME}" $green
	cecho "\tTarget ESX(i) host: ${ESXI_HOSTNAME}" $green

	cecho "\ny|n?" $yellow

	read RESPONSE
        case "$RESPONSE" in [yY]|yes|YES|Yes)
                ;;
                *) cecho "Quiting installation!" $red
                exit 1
                ;;
        esac
}

deployvINOVA() {
	OVFTOOl_BIN=/usr/bin/ovftool

	if [ ! -e ${OVFTOOl_BIN} ]; then
		cecho "ovftool does not look like it's installed!" $red
		exit 1
	fi

	cecho "Deploying VMware vCenter Infrastructure Navigator Virtual Appliance: ${VIN_DISPLAY_NAME} ..." $cyan
	${OVFTOOl_BIN}  --acceptAllEulas --skipManifestCheck "--net:Network 1=${VIN_PORTGROUP}" --datastore=${VIN_DATASTORE} --diskMode=${VIN_DISK_TYPE} --name=${VIN_DISPLAY_NAME} --prop:vami.DNS.vCenter_Infrastructure_Navigator=${VIN_DNS} --prop:vami.gateway.vCenter_Infrastructure_Navigator=${VIN_GATEWAY} --prop:vami.ip0.vCenter_Infrastructure_Navigator=${VIN_IPADDRESS} --prop:vami.netmask0.vCenter_Infrastructure_Navigator=${VIN_NETMASK} --prop:vm.password=${VIN_PASSWORD} ${VIN_OVA} vi://${VCENTER_USERNAME}:${VCENTER_PASSWORD}@${VCENTER_HOSTNAME}/?dns=${ESXI_HOSTNAME}
}

verify
deployvINOVA
cecho "VMware vCenter Infrastructure Navigator Virtual Appliance ${VIN_DISPLAY_NAME} has successfully been deployed!" $cyan
