#!/bin/bash
# Author: William Lam
# Site: www.williamlam.com

OVFTOOL="/Applications/VMware OVF Tool/ovftool"
VCF_LICENSE_SERVER_OVA="/Volumes/Storage/Software/VCF9100400/Vcf-License-Server-9.1.0.0400.25541557.ova"

ESXI_HOST="esx02.vcf.lab"
ESXI_USERNAME="root"
ESXI_PASSWORD='VMware1!'
VM_NETWORK="DVPG_FOR_VM_MANAGEMENT"
VM_DATASTORE="vsanDatastore"
VCF_LICENSE_SERVER_VMNAME=vcf-lic04
VCF_LICENSE_SERVER_HOSTNAME=vcf-lic04.vcf.lab
VCF_LICENSE_SERVER_IP=172.30.0.101
VCF_LICENSE_SERVER_SUBNET=255.255.255.0
VCF_LICENSE_SERVER_GATEWAY=172.30.0.1
VCF_LICENSE_SERVER_DNS_SERVER=192.168.30.29
VCF_LICENSE_SERVER_DNS_DOMAIN=vcf.lab
VCF_LICENSE_SERVER_DNS_SEARCH=vcf.lab
VCF_OPERATIONS_LICENSE_SERVER_REGISTRATION_CODE="FILL_ME_IN"

### DO NOT EDIT BEYOND HERE ###

echo -e "\nDeploying VCF License Server ${VCF_LICENSE_SERVER_VMNAME} to ESX host ..."
"${OVFTOOL}" --acceptAllEulas --noSSLVerify --skipManifestCheck --X:injectOvfEnv --allowExtraConfig --X:waitForIp --sourceType=OVA --powerOn \
"--net:Network 1=${VM_NETWORK}" --datastore=${VM_DATASTORE} --diskMode=thin --name=${VCF_LICENSE_SERVER_VMNAME} \
"--prop:hostname=${VCF_LICENSE_SERVER_HOSTNAME}" \
"--prop:otk=${VCF_OPERATIONS_LICENSE_SERVER_REGISTRATION_CODE}" \
"--prop:gateway.VCF_License_Server_Appliance=${VCF_LICENSE_SERVER_GATEWAY}" \
"--prop:domain.VCF_License_Server_Appliance=${VCF_LICENSE_SERVER_DNS_DOMAIN}" \
"--prop:searchpath.VCF_License_Server_Appliance=${VCF_LICENSE_SERVER_DNS_SEARCH}" \
"--prop:dns.VCF_License_Server_Appliance=${VCF_LICENSE_SERVER_DNS_SERVER}" \
"--prop:ip0.VCF_License_Server_Appliance=${VCF_LICENSE_SERVER_IP}" \
"--prop:netmask0.VCF_License_Server_Appliance=${VCF_LICENSE_SERVER_SUBNET}" \
${VCF_LICENSE_SERVER_OVA} "vi://${ESXI_USERNAME}:${ESXI_PASSWORD}@${ESXI_HOST}/"