#!/bin/bash
# Author: William Lam
# Website: www.virtuallyghetto.com
# Product: VMware Horizon View
# Description: Automating Horizon View deployment
# Reference: http://www.virtuallyghetto.com/2014/03/automating-horizon-view-deployments-using-vct-curl.html

VCT_IP=172.30.0.160

## ------ Page 1 ESXi ------ ##

## ESXi Section ##
ESXI_IP=172.30.0.98
ESXI_USERNAME=root
ESXI_PASSWORD=vmware123
ESXI_DATASTORE=datastore1
ESXI_NETWORK="VM Network"

WINDOWS_ISO=win2k8.iso

STUDIO_IP=172.30.0.161
STUDIO_PASSWORD=vmware123

## ------ Page 2 Domain Controller (AD) ------ ##

# Existing AD, set to PROD
# New AD, set to PROAD
VERSION=PRODAD

## AD Domain Setup Information ##
AD_COMPUTER_NAME=ActiveDirectory
AD_PASSWORD=VMware123!
AD_OWNER=virtuallyghetto
AD_ORGANIZATION=virtuallyghetto
AD_WINDOWS_KEY=

AD_DOMAIN_NAME=domain.corp.local
AD_NETBIOS_NAME=domain
AD_SAFEMODE_PASSWORD=VMware123!

## DHCP for DC ##
AD_DHCP_SERVER=172.30.0.162
AD_DHCP_NETMASK=255.255.255.0
AD_DHCP_GATEWAY=172.30.0.1

# Below is only required for brand new AD
AD_DHCP_SCOPE=172.30.0.0
AD_DHCP_SCOPE_RANGE_START=172.30.0.170
AD_DHCP_SCOPE_RANGE_END=172.30.0.175
AD_DHCP_SCOPE_EXCLUDE_START=
AD_DHCP_SCOPE_EXCLUDE_END=

## ------ Page 3 VCSA ------ ##
VCSA_NAME=VMware-VCSA
VCSA_IP=172.30.0.163
VCSA_NETMASK=255.255.255.0
VCSA_GATEWAY=172.30.0.1

## ------ Page 4 View ------ ##
VIEW_COMPUTER_NAME=VMware-View
VIEW_IP=172.30.0.164
VIEW_NETMASK=255.255.255.0
VIEW_GATEWAY=172.30.0.1
VIEW_PASSWORD=VMware123!
VIEW_OWNER=virtuallyghetto
VIEW_ORGANIZATION=virtuallyghetto
VIEW_WINDOWS_KEY=
VIEW_RECOVERY_PASSWORD=VMware123!

## ------ Page 5 View Composer ------ ##
VIEW_COMPOSER_COMPUTER_NAME=VMware-Composer
VIEW_COMPOSER_IP=172.30.0.165
VIEW_COMPOSER_NETMASK=255.255.255.0
VIEW_COMPOSER_GATEWAY=172.30.0.1
VIEW_COMPOSER_PASSWORD=VMware123!
VIEW_COMPOSER_OWNER=virtuallyghetto
VIEW_COMPOSER_ORGANIZATION=virtuallyghetto
VIEW_COMPOSER_WINDOWS_KEY=

#### DO NOT EDIT ####
AD_DOMAIN_FUNCTION_LEVEL=Windows+Server+2003+Function+Level
AD_DOMAIN_FOREST_FUNCTION_LEVEL=Windows+Server+2003+Function+Level
AD_DATABASE_PATH=C%3A%5CWindows%5CNTDS
AD_SYSVOL_PATH=C%3A%5CWindows%5CSYSVOL
AD_LOG_PATH=C%3A%5CWindows%5CNTDS
VIEW_SERVER_BIN=VMware-viewconnectionserver-x86_64-5.3.0-1427931.exe
VIEW_COMPOSER_BIN=VMware-viewcomposer-5.3.0-1427647.exe
VCSA_OVA=VMware-vCenter-Server-Appliance-5.5.0.5201-1476389_OVF10.ova

# VCT payload
cat > /tmp/request << __REQUEST__ 
version=${VERSION}&esxi_url=${ESXI_IP}&win8_iso_name=${WINDOWS_ISO}&esxi_userid=${ESXI_USERNAME}&esxi_password=${ESXI_PASSWORD}&esxi_network=${ESXI_NETWORK}&esxi_datastore=${ESXI_DATASTORE}&viewcs_exe_name=${VIEW_SERVER_BIN}&composer_exe_name=${VIEW_COMPOSER_BIN}&vCenter_exe_name=${VCSA_OVA}&studio_ip_address=${STUDIO_IP}&studio_password=${STUDIO_PASSWORD}&ad_comp_name=${AD_COMPUTER_NAME}&ad_owner_name=${AD_OWNER}&ad_organization_name=${AD_ORGANIZATION}&ad_product_key=${AD_WINDOWS_KEY}&ad_comp_pw=${AD_PASSWORD}&gateway=${AD_DHCP_GATEWAY}&subnet_mask=${AD_DHCP_NETMASK}&vcomp_owner_name=${VIEW_COMPOSER_OWNER}&vcomp_organization_name=${VIEW_COMPOSER_ORGANIZATION}&vcomp_product_key=${VIEW_COMPOSER_WINDOWS_KEY}&view_owner_name=${VIEW_OWNER}&view_organization_name=${VIEW_ORGANIZATION}&view_product_key=${VIEW_WINDOWS_KEY}&addns_name=${AD_DOMAIN_NAME}&ad_netbios_name=${AD_NETBIOS_NAME}&ad_df_level=${AD_DOMAIN_FOREST_FUNCTION_LEVEL}&ad_ff_level=${AD_DOMAIN_FUNCTION_LEVEL}&ad_db_path=${AD_DATABASE_PATH}&ad_sysvol_path=${AD_SYSVOL_PATH}&ad_log_path=${AD_LOG_PATH}&ad_safe_mode_pw=${AD_SAFEMODE_PASSWORD}&dhcp_server=${AD_DHCP_SERVER}&dhcp_scope=${AD_DHCP_SCOPE}&dhcp_scope_rangelow=${AD_DHCP_SCOPE_RANGE_START}&dhcp_scope_rangehigh=${AD_DHCP_SCOPE_RANGE_END}&dhcp_scope_exrangelow=${AD_DHCP_SCOPE_EXCLUDE_START}&dhcp_scope_exrangehigh=${AD_DHCP_SCOPE_EXCLUDE_END}&vc_subnet_mask=${VCSA_NETMASK}&vc_gateway=${VIEW_GATEWAY}&view_ip=${VIEW_IP}&view_subnet_mask=${VIEW_NETMASK}&view_gateway=${VIEW_GATEWAY}&view_comp_name=${VIEW_COMPUTER_NAME}&view_comp_pw=${VIEW_PASSWORD}&viewcs_drpassword=${VIEW_RECOVERY_PASSWORD}&vc_ip=${VCSA_IP}&vc_name=${VCSA_NAME}&vcomp_ip=${VIEW_COMPOSER_IP}&vcomp_subnet_mask=${VIEW_COMPOSER_NETMASK}&vcomp_gateway=${VIEW_COMPOSER_GATEWAY}&vcomp_comp_name=${VIEW_COMPOSER_COMPUTER_NAME}&vcomp_comp_pw=${VIEW_COMPOSER_PASSWORD}
__REQUEST__

echo "Sending Horizon View Provisioning Request to VCT ..."
curl -s -k -H "Content-Type:application/x-www-form-urlencoded" -X POST http://${VCT_IP}/vct/VCT -d @/tmp/request &

while :;
do
	sleep 10
	echo -e "\nCurrent Status:"
	curl -s -k -H "Content-Type:application/x-www-form-urlencoded" -X GET http://${VCT_IP}/vct/VCT
done
