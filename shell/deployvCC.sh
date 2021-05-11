#!/bin/bash
# Author: William Lam
# Website: www.williamlam.com
# Product: VMware vCloud Connector
# Description: Wrapper script to deploy VMware vCloud Connector Server/Node Virtual Apppliance
# Reference: http://www.williamlam.com/2011/11/unattended-deployment-of-vcloud.html

# Configurations 

# vCC Server OVF
VCC_SERVER_OVF=vCCServer-1.5.0.0-515166_OVF10.ovf

# vCC Node OVF
VCC_NODE_OVF=vCCNode-1.5.0.0-515165_OVF10.ovf

# vCC Server Deployment
VCC_SERVER_DISPLAY_NAME=vcc-server
VCC_SERVER_HOSTNAME=vcc-server.primp-industries.com
VCC_SERVER_PORTGROUP=VM_Network
VCC_SERVER_DATASTORE=vesxi50-1-local-storage-1
VCC_SERVER_DISK_TYPE=thin
VCC_SERVER_IPADDRESS=172.30.0.143
VCC_SERVER_NETMASK=255.255.255.0
VCC_SERVER_GATEWAY=172.30.0.1
VCC_SERVER_DNS=172.30.0.100
VCC_SERVER_IPPROTOCOL=IPv4

# vCC Node Deployment
VCC_NODE_DISPLAY_NAME=vcc-node
VCC_NODE_HOSTNAME=vcc-node.primp-industries.com
VCC_NODE_PORTGROUP=VM_Network
VCC_NODE_DATASTORE=vesxi50-1-local-storage-1
VCC_NODE_DISK_TYPE=thin
VCC_NODE_IPADDRESS=172.30.0.144
VCC_NODE_NETMASK=255.255.255.0
VCC_NODE_GATEWAY=172.30.0.1
VCC_NODE_DNS=172.30.0.100
VCC_NODE_IPPROTOCOL=IPv4

# vCenter or ESX(i)
VCENTER_HOSTNAME=vcenter50-3.primp-industries.com
VCENTER_USERNAME=root
VCENTER_PASSWORD=vmware
ESXI_HOSTNAME=vesxi50-1.primp-industries.com

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

deployvCCServerOVF() {
	OVFTOOl_BIN=/usr/bin/ovftool

	cecho "Would you like to deploy vCC Server?" $yellow
        cecho "y|n?" $yellow

        read RESPONSE
        case "$RESPONSE" in [yY]|yes|YES|Yes)
		INSTALL_VCC_SERVER=yes
                ;;
                *) cecho "Quiting installation!" $red
		INSTALL_VCC_SERVER=no
                ;;
        esac

	if [ ${INSTALL_VCC_SERVER} == "yes" ]; then
                if [ ! -e ${OVFTOOl_BIN} ]; then
                        cecho "ovftool does not look like it's installed!" $red
                        exit 1
                fi

	        if [ ! -e ${VCC_SERVER_OVF} ]; then
        	        cecho "Unable to locate \"${VCC_SERVER_OVF}\"!" $red
                	exit 1
	        fi

	        cecho "Would you like to deploy the following configuration for vCloud Connector Server?" $yellow
        	cecho "\tVMware vCloud Connector Server Virtual Appliance: ${VCC_SERVER_OVF}" $green
	        cecho "\tvCC Server Display Name: ${VCC_SERVER_DISPLAY_NAME}" $green
        	cecho "\tvCC Server Hostname: ${VCC_SERVER_HOSTNAME}" $green
	        cecho "\tvCC Server IP Address: ${VCC_SERVER_IPADDRESS}" $green
        	cecho "\tvCC Server Netmask: ${VCC_SERVER_NETMASK}" $green
	        cecho "\tvCC Server Gateway: ${VCC_SERVER_GATEWAY}" $green
        	cecho "\tvCC Server DNS: ${VCC_SERVER_DNS}" $green
	        cecho "\tvCC Server Portgroup: ${VCC_SERVER_PORTGROUP}" $green
        	cecho "\tvCC Server Datastore: ${VCC_SERVER_DATASTORE}" $green
	        cecho "\tvCC Server Disk Type: ${VCC_SERVER_DISK_TYPE}" $green
        	cecho "\tvCenter Server: ${VCENTER_HOSTNAME}" $green
	        cecho "\tTarget ESX(i) host: ${ESXI_HOSTNAME}" $green

        	cecho "\ny|n?" $yellow

	        read RESPONSE
        	case "$RESPONSE" in [yY]|yes|YES|Yes)
			INSTALL_VCC_SERVER=yes
	                ;;
        	        *) cecho "Quiting installation!" $red
			INSTALL_VCC_SERVER=no
	                ;;
        	esac

		if [ ${INSTALL_VCC_SERVER} == "yes" ]; then
			cecho "Deploying VMware vCloud Connector Server Virtual Appliance: ${VCC_SERVER_DISPLAY_NAME} ..." $cyan
			${OVFTOOl_BIN}  --acceptAllEulas --skipManifestCheck "--net:Network 1=${VCC_SERVER_PORTGROUP}" --datastore=${VCC_SERVER_DATASTORE} --diskMode=${VCC_SERVER_DISK_TYPE} --name=${VCC_SERVER_DISPLAY_NAME} --prop:vami.DNS.VMware_vCloud_Connector_Server=${VCC_SERVER_DNS} --prop:vami.gateway.VMware_vCloud_Connector_Server=${VCC_SERVER_GATEWAY} --prop:vami.ip0.VMware_vCloud_Connector_Server=${VCC_SERVER_IPADDRESS} --prop:vami.netmask0.VMware_vCloud_Connector_Server=${VCC_SERVER_NETMASK} ${VCC_SERVER_OVF} vi://${VCENTER_USERNAME}:${VCENTER_PASSWORD}@${VCENTER_HOSTNAME}/?dns=${ESXI_HOSTNAME}
		fi
	fi
}

deployvCCNodeOVF() {
        OVFTOOl_BIN=/usr/bin/ovftool
	
	cecho "Would you like to deploy vCC Node?" $yellow
        cecho "y|n?" $yellow

        read RESPONSE
        case "$RESPONSE" in [yY]|yes|YES|Yes)
		INSTALL_VCC_NODE=yes
                ;;
                *) cecho "Quiting installation!" $red
		INSTALL_VCC_NODE=no
                exit 1
                ;;
        esac

	if [ ${INSTALL_VCC_NODE} == "yes" ]; then
		if [ ! -e ${OVFTOOl_BIN} ]; then
                        cecho "ovftool does not look like it's installed!" $red
                        exit 1
                fi

	        if [ ! -e ${VCC_NODE_OVF} ]; then
        	        cecho "Unable to locate \"${VCC_NODE_OVF}\"!" $red
                	exit 1
	        fi

        	cecho "Would you like to deploy the following configuration for vCloud Connector Node?" $yellow
        	cecho "\tVMware vCloud Connector Node Virtual Appliance: ${VCC_NODE_OVF}" $green
	        cecho "\tvCC Node Display Name: ${VCC_NODE_DISPLAY_NAME}" $green
	        cecho "\tvCC Nde Hostname: ${VCC_NODE_HOSTNAME}" $green
        	cecho "\tvCC Node IP Address: ${VCC_NODE_IPADDRESS}" $green
	        cecho "\tvCC Node Netmask: ${VCC_NODE_NETMASK}" $green
        	cecho "\tvCC Node Gateway: ${VCC_NODE_GATEWAY}" $green
	        cecho "\tvCC Node DNS: ${VCC_NODE_DNS}" $green
        	cecho "\tvCC Node Portgroup: ${VCC_NODE_PORTGROUP}" $green
	        cecho "\tvCC Node Datastore: ${VCC_NODE_DATASTORE}" $green
        	cecho "\tvCc Node Disk Type: ${VCC_NODE_DISK_TYPE}" $green
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

       	cecho "Deploying VMware vCloud Connector Node Virtual Appliance: ${VCC_NODE_DISPLAY_NAME} ..." $cyan
        ${OVFTOOl_BIN}  --acceptAllEulas --skipManifestCheck "--net:Network 1=${VCC_NODE_PORTGROUP}" --datastore=${VCC_NODE_DATASTORE} --diskMode=${VCC_NODE_DISK_TYPE} --name=${VCC_NODE_DISPLAY_NAME} --prop:vami.DNS.VMware_vCloud_Connector_Node=${VCC_NODE_DNS} --prop:vami.gateway.VMware_vCloud_Connector_Node=${VCC_NODE_GATEWAY} --prop:vami.ip0.VMware_vCloud_Connector_Node=${VCC_NODE_IPADDRESS} --prop:vami.netmask0.VMware_vCloud_Connector_Node=${VCC_NODE_NETMASK} ${VCC_NODE_OVF} vi://${VCENTER_USERNAME}:${VCENTER_PASSWORD}@${VCENTER_HOSTNAME}/?dns=${ESXI_HOSTNAME}
	fi
}

deployvCCServerOVF
deployvCCNodeOVF
