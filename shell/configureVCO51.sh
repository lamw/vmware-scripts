#!/bin/bash
# Author: William Lam
# Website: www.virtuallyghetto.com
# Product: VMware vCenter Orchestrator
# Description: Script to automate the configuration of vCO 5.1
# Reference: http://www.virtuallyghetto.com/2012/09/quickly-configuring-new-vcenter.html

VCO_IP_ADDRESS=172.30.0.203
VCO_DEFAULT_USERNAME=vmware
VCO_DEFAULT_PASSWORD=vmware
VCO_NEW_PASSWORD=vmware123

VCENTER_IP_ADDRESS=172.30.0.181
SSO_IP_ADDRESS=172.30.0.181
VCENTER_USERNAME=root
VCENTER_PASSWORD=vmware

### DO NOT EDIT PASS THIS ###

initialLogin() {
	VCO_TEMP=/tmp/vco-config-$$
	mkdir -p ${VCO_TEMP}
	curl -s -o /dev/null -w "%{http_code}" -c ${VCO_TEMP}/cookie -i -k -H "Content-Type:application/x-www-form-urlencoded" -X POST https://${VCO_IP_ADDRESS}:8283/j_security_check -d"j_username=${VCO_DEFAULT_USERNAME}" -d"j_password=${VCO_DEFAULT_PASSWORD}"
	echo " Initial Login to ${VCO_IP_ADDRESS}"
}

changeDefaultPass() {
	curl -s -o /dev/null -w "%{http_code}" -i -k -H "Content-Type:application/x-www-form-urlencoded" -b ${VCO_TEMP}/cookie -X POST https://${VCO_IP_ADDRESS}:8283/config_general/ForceChangePassword_save.action -d"newPassword=${VCO_NEW_PASSWORD}" -d"newPasswordConfirmation=${VCO_NEW_PASSWORD}"
	echo " Changing Default VCO Password"
}
	
importSSOServerSSLCert() {
	cat > ${VCO_TEMP}/importssl-body << __SSO_SSL_CERT__
remoteServerUrl=${SSO_IP_ADDRESS}
__SSO_SSL_CERT__
	
	curl -s -o /dev/null -w "%{http_code}" -i -k -H "Content-Type:application/x-www-form-urlencoded" -b ${VCO_TEMP}/cookie -X POST https://${VCO_IP_ADDRESS}:8283/config_network/NetworkImportRemoteCertificate.action -d @${VCO_TEMP}/importssl-body
	echo " Import SSO Server SSL Cert from ${SSO_IP_ADDRESS}"
}

approveSSOServerSSLCert() {
	curl -s -o /dev/null -w "%{http_code}" -i -k -H "Content-Type:application/x-www-form-urlencoded" -b ${VCO_TEMP}/cookie -X GET https://${VCO_IP_ADDRESS}:8283/config_network/NetworkApproveRemoteCertificate.action?requestType=1
	echo " Approve SSO Server SSL Cert"
}

registerSSOServer() {
	cat > ${VCO_TEMP}/register-body << __REGISTER_SSO__
authenticationMode=sso&ssoBasicHost=https%3A%2F%2F${VCENTER_IP_ADDRESS}%3A7444&ssoUsername=${VCENTER_USERNAME}&ssoPassword=${VCENTER_PASSWORD}
__REGISTER_SSO__

	curl -s -o /dev/null -w "%{http_code}" -i -k -H "Content-Type:application/x-www-form-urlencoded" -b ${VCO_TEMP}/cookie -X POST https://${VCO_IP_ADDRESS}:8283/config_authentication/RegisterSSO.action -d @${VCO_TEMP}/register-body
	echo " Register SSO Server ${SSO_IP_ADDRESS}"
}

confirmSSOServer() {
	cat > ${VCO_TEMP}/approve-body << __CONFIRM_SSO__
adminGroup=System-Domain%5C__Administrators__&ssoBasicHost=https%3A%2F%2F${VCENTER_IP_ADDRESS}%3A7444&ssoUsername=${VCENTER_USERNAME}&authenticationModeName=SSO%20Authentication&ssoClockTolerance=300
__CONFIRM_SSO__

	curl -s -o /dev/null -w "%{http_code}" -i -k -H "Content-Type:application/x-www-form-urlencoded" -b ${VCO_TEMP}/cookie -X POST https://${VCO_IP_ADDRESS}:8283/config_authentication/ApproveSSO.action -d @${VCO_TEMP}/approve-body
	echo " Confirm SSO Server"
}
	
listVCOPlugins() {
	curl -s -o /dev/null -w "%{http_code}" -i -k -H "Content-Type:application/x-www-form-urlencoded" -b ${VCO_TEMP}/cookie -X GET https://${VCO_IP_ADDRESS}:8283/config_plugin/Plugin.action
	echo " List VCO Plugins"
}

enablevCenterPlugin() {
	cat > ${VCO_TEMP}/plugin-body << __ENABLE_VC__
installPasswordSecured=${VCENTER_PASSWORD}&installUsername=${VCENTER_USERNAME}&pluginList[9].enabled=true
__ENABLE_VC__

	curl -s -o /dev/null -w "%{http_code}" -i -k -H "Content-Type:application/x-www-form-urlencoded" -b ${VCO_TEMP}/cookie -X POST https://${VCO_IP_ADDRESS}:8283/config_plugin/PluginSave.action -d @${VCO_TEMP}/plugin-body
	echo " Enable vCenter Plugin"
}

navigateTovCenterPlugin() {
	curl -s -o /dev/null -w "%{http_code}" -i -k -H "Content-Type:application/x-www-form-urlencoded" -b ${VCO_TEMP}/cookie -X GET https://${VCO_IP_ADDRESS}:8283/o11nplugin-vsphere50-config/Default.action
	echo " Navigating to vCenter Plugin Page"
	curl -s -o /dev/null -w "%{http_code}" -i -k -H "Content-Type:application/x-www-form-urlencoded" -b ${VCO_TEMP}/cookie -X GET https://${VCO_IP_ADDRESS}:8283/o11nplugin-vsphere50-config/AddVCHost.action
	echo " Navigating to Add vCenter Host Page"
}

registervCenterServer() {
	cat > ${VCO_TEMP}/vc-body << __REGISTER_VC__
selectedAvailableType=Enabled&hostField=${VCENTER_IP_ADDRESS}&portField=443&secureChannelField=true&__checkbox_secureChannelField=true&pathField=%2Fsdk&sessionMode=2&usernameField=${VCENTER_USERNAME}&passwordField=${VCENTER_PASSWORD}&rowIndex=0&addNew=true
__REGISTER_VC__
	
	curl -s -o /dev/null -w "%{http_code}" -i -k -H "Content-Type:application/x-www-form-urlencoded" -b ${VCO_TEMP}/cookie -X POST https://${VCO_IP_ADDRESS}:8283/o11nplugin-vsphere50-config/SaveConfiguration.action -d @${VCO_TEMP}/vc-body
	echo " Register vCenter Server ${VCENTER_IP_ADDRESS}"
}

restartVCOService() {
	curl -s -o /dev/null -w "%{http_code}" -i -k -H "Content-Type:application/x-www-form-urlencoded" -b ${VCO_TEMP}/cookie -X GET https://${VCO_IP_ADDRESS}:8283/config_server/config_server/Server_restart.action
	echo " Restart VCO Service for changes to go into effect"
	echo "You can now access the vCO Configuration page by going to https://${VCO_IP_ADDRESS}:8283"
	echo "You can now access the VCO Server in vSphere Web Client by going to https://${VCENTER_IP_ADDRESS}:9443/vsphere-client"
}


initialLogin
changeDefaultPass
importSSOServerSSLCert
approveSSOServerSSLCert
registerSSOServer
confirmSSOServer
listVCOPlugins
enablevCenterPlugin
navigateTovCenterPlugin
registervCenterServer
restartVCOService
