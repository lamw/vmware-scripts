#!/bin/bash

# William Lam
# http://www.virtuallyghetto.com/
# Wrapper script to deploy VMware vShield Manager 
# and automatically configure static IP Address
##############################################################

# Configurations 

# vShield OVF
VSM_OVA=VMware-vShield-Manager-5.0.0-473791.ova

# e.g. 172.30.0.141/24 
VSM_DISPLAY_NAME=vSM
VSM_HOSTNAME=vsm.primp-industries.com
VSM_PORTGROUP=VMNetwork3
VSM_DATASTORE=vesxi50-4-local-storage-1
VSM_DISK_TYPE=thin
VSM_IPADDRESS=172.30.0.141
VSM_IPCIDR=24
VSM_GATEWAY=172.30.0.1

# vCenter or ESX(i)
VCENTER_HOSTNAME=vcenter50-2.primp-industries.com
VCENTER_USERNAME=root
VCENTER_PASSWORD=vmware
ESXI_HOSTNAME=vesxi50-4.primp-industries.com

############## DO NOT EDIT BEYOND HERE #################

VSM_ADMIN_ACCOUNT=admin
VSM_ADMIN_PASSWORD=default

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
	if [ ! -e ${VSM_OVA} ]; then
		cecho "Unable to locate \"${VSM_OVA}\"!" $red
		exit 1
	fi

	cecho "Would you like to deploy the following configuration for vShield Manager?" $yellow
	cecho "\tVMware vShield Manager OVA: ${VSM_OVA}" $green
	cecho "\tvSM Display Name: ${VSM_DISPLAY_NAME}" $green
	cecho "\tvSM Hostname: ${VSM_HOSTNAME}" $green
	cecho "\tvSM IP Address: ${VSM_IPADDRESS}/${VSM_IPCIDR}" $green
	cecho "\tvSM Gateway: ${VSM_GATEWAY}" $green
	cecho "\tvSM Portgroup: ${VSM_PORTGROUP}" $green
	cecho "\tvSM Datastore: ${VSM_DATASTORE}" $green
	cecho "\tvSM Disk Type: ${VSM_DISK_TYPE}" $green
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

deployvSMOVA() {
	OVFTOOl_BIN=/usr/bin/ovftool

	if [ ! -e ${OVFTOOl_BIN} ]; then
		cecho "ovftool does not look like it's installed!" $red
		exit 1
	fi

	cecho "Deploying VMware vShield Manager: ${VSM_DISPLAY_NAME} ..." $cyan
	${OVFTOOl_BIN} --acceptAllEulas \
			--net:VSMgmt=${VSM_PORTGROUP} \
			--datastore=${VSM_DATASTORE} \
			--diskMode=${VSM_DISK_TYPE} --name=${VSM_DISPLAY_NAME} \
			${VSM_OVA} \
			vi://${VCENTER_USERNAME}:${VCENTER_PASSWORD}@${VCENTER_HOSTNAME}/?dns=${ESXI_HOSTNAME}
}

powerOpvSM() {
	local POWEROP=$1
	local SLEEPTIME=$2

	if [ ! -e /usr/lib/vmware-vcli/apps/vm/vmcontrol.pl ]; then
		cecho "Unable to locate \"/usr/lib/vmware-vcli/apps/vm/vmcontrol.pl\" to power${POWEROP} vSM!" $red
		exit 1
	fi

	cecho "Powering ${POWEROP} ${VSM_DISPLAY_NAME} ..." $cyan
	/usr/lib/vmware-vcli/apps/vm/vmcontrol.pl --server ${VCENTER_HOSTNAME} --username ${VCENTER_USERNAME} --password ${VCENTER_PASSWORD} --vmname "${VSM_DISPLAY_NAME}" --operation power${POWEROP} > /dev/null 2>&1

	cecho "Sleeping for ${SLEEPTIME}seconds while ${VSM_DISPLAY_NAME} is being powered ${POWEROP} ..." $cyan
	sleep ${SLEEPTIME}
}

createZebraConf() {
	cecho "Creating vSM zebra.conf configuration file ..." $cyan
	cat > zebra.conf << __ZEBRA_CONF__
!
hostname  ${VSM_HOSTNAME}
!
interface mgmt
 ip address ${VSM_IPADDRESS}/${VSM_IPCIDR}
!
ip route 0.0.0.0/0 ${VSM_GATEWAY}
!
line vty
 no login
!
web-manager
!
__ZEBRA_CONF__
}

uploadZebraConf() {
	if [ ! -e guestOpsManagement.pl ]; then
		cecho "Unable to locate \"guestOpsManagement.pl\" script!" $red
		exit 1
	fi

	echo "yes" > /tmp/guestOpsAnswerFile

	cecho "Renaming old vSM zebra.conf to vSM /common/configs/cli/zebra.conf.bak ..." $cyan
	./guestOpsManagement.pl --server ${VCENTER_HOSTNAME} --username ${VCENTER_USERNAME} --password ${VCENTER_PASSWORD} --vm ${VSM_DISPLAY_NAME} --guestusername ${VSM_ADMIN_ACCOUNT} --guestpassword ${VSM_ADMIN_PASSWORD} --operation mv --filepath_src /common/configs/cli/zebra.conf --filepath_dst /common/configs/cli/zebra.conf.bak < /tmp/guestOpsAnswerFile

	cecho "Uploading vSM zebra.conf to vSM /common/configs/cli/zebra.conf ..." $cyan
	./guestOpsManagement.pl --server ${VCENTER_HOSTNAME} --username ${VCENTER_USERNAME} --password ${VCENTER_PASSWORD} --vm ${VSM_DISPLAY_NAME} --guestusername ${VSM_ADMIN_ACCOUNT} --guestpassword ${VSM_ADMIN_PASSWORD} --operation copytoguest --filepath_src zebra.conf --filepath_dst /common/configs/cli/zebra.conf

	echo "Sleeping 20seconds to ensure files are persisted prior to powering off..."
	sleep 20
}

verify
deployvSMOVA
powerOpvSM on 120
createZebraConf
uploadZebraConf
powerOpvSM off 30
powerOpvSM on 60
cecho "vShield Manager ${VSM_DISPLAY_NAME} has successfully been deployed!" $cyan
