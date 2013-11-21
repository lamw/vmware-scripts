#!/bin/bash

# William Lam
# http://www.virtuallyghetto.com/
# Wrapper script to deploy VMware vCloud Director Virtual Apppliance
#####################################################################

# Configurations 

# vCD OVF
VCD_OVA=vCloud_Director_VA_CentoOS5-1.5.0.0-525550_OVF10.ova

VCD_DISPLAY_NAME=vcd
VCD_HOSTNAME=vcd.primp-industries.com
VCD_HTTP_PORTGROUP=VM_Network
VCD_CONSOLE_PORTGROUP=VM_Network
VCD_DATASTORE=vesxi50-2-local-storage-1
VCD_DISK_TYPE=thin
VCD_HTTP_IPADDRESS=172.30.0.148
VCD_HTTP_NETMASK=255.255.255.0
VCD_CONSOLE_IPADDRESS=172.30.0.149
VCD_CONSOLE_NETMASK=255.255.255.0
VCD_GATEWAY=172.30.0.1
VCD_DNS=172.30.0.100
VCD_IPPROTOCOL=IPv4

# vCenter or ESX(i)
VCENTER_HOSTNAME=vcenter50-3.primp-industries.com
VCENTER_USERNAME=root
VCENTER_PASSWORD=vmware
ESXI_HOSTNAME=vesxi50-2.primp-industries.com

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
	if [ ! -e ${VCD_OVA} ]; then
		cecho "Unable to locate \"${VCD_OVA}\"!" $red
		exit 1
	fi

	cecho "Would you like to deploy the following configuration for vCloud Director?" $yellow
	cecho "\tVMware vCloud Director Virtual Appliance: ${VCD_OVA}" $green
	cecho "\tvCD Display Name: ${VCD_DISPLAY_NAME}" $green
	cecho "\tvCD Hostname: ${VCD_HOSTNAME}" $green
	cecho "\tvCD HTTP IP Address: ${VCD_HTTP_IPADDRESS}" $green
	cecho "\tvCD HTTP Netmask: ${VCD_HTTP_NETMASK}" $green
	cecho "\tvCD Console IP Address: ${VCD_CONSOLE_IPADDRESS}" $green
	cecho "\tvCD Console Netmask: ${VCD_CONSOLE_NETMASK}" $green
	cecho "\tvCD Gateway: ${VCD_GATEWAY}" $green
	cecho "\tvCD DNS: ${VCD_DNS}" $green
	cecho "\tvCD HTTP Portgroup: ${VCD_HTTP_PORTGROUP}" $green
	cecho "\tvCD Console Portgroup: ${VCD_CONSOLE_PORTGROUP}" $green
	cecho "\tvCD Datastore: ${VCD_DATASTORE}" $green
	cecho "\tvCD Disk Type: ${VCD_DISK_TYPE}" $green
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

deployvCDOVA() {
	OVFTOOl_BIN=/usr/bin/ovftool

	if [ ! -e ${OVFTOOl_BIN} ]; then
		cecho "ovftool does not look like it's installed!" $red
		exit 1
	fi

	cecho "Deploying VMware vCloud Director Virtual Appliance: ${VCD_DISPLAY_NAME} ..." $cyan
	${OVFTOOl_BIN}  --acceptAllEulas --skipManifestCheck "--net:Network 1=${VCD_HTTP_PORTGROUP}" "--net:Network 2=${VCD_CONSOLE_PORTGROUP}" --datastore=${VCD_DATASTORE} --diskMode=${VCD_DISK_TYPE} --name=${VCD_DISPLAY_NAME} --prop:vami.DNS.VMware_vCloud_Director=${VCD_DNS} --prop:vami.gateway.VMware_vCloud_Director=${VCD_GATEWAY} --prop:vami.ip0.VMware_vCloud_Director=${VCD_HTTP_IPADDRESS} --prop:vami.netmask0.VMware_vCloud_Director=${VCD_HTTP_NETMASK} --prop:vami.ip1.VMware_vCloud_Director=${VCD_CONSOLE_IPADDRESS} --prop:vami.netmask1.VMware_vCloud_Director=${VCD_CONSOLE_NETMASK} ${VCD_OVA} vi://${VCENTER_USERNAME}:${VCENTER_PASSWORD}@${VCENTER_HOSTNAME}/?dns=${ESXI_HOSTNAME}
}

verify
deployvCDOVA
cecho "VMware vCloud Director Virtual Appliance ${VCD_DISPLAY_NAME} has successfully been deployed!" $cyan
