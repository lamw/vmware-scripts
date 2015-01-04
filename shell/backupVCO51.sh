#!/bin/bash
# Author: William Lam
# Website: www.virtuallyghetto.com
# Product: VMware vCenter Orchestrator
# Description: Automating vCO config backup
# Reference: http://www.virtuallyghetto.com/2013/03/automate-vcenter-orchestrator.html

VCO_IP_ADDRESS=vco.primp-industries.com
VCO_USERNAME=vmware
VCO_PASSWORD=MySuperDuperSecretPassword!

initialLogin() {
	VCO_TEMP=/tmp/vco-config-$$
	mkdir -p ${VCO_TEMP}
	curl -s -o /dev/null -w "%{http_code}" -c ${VCO_TEMP}/cookie -i -k -H "Content-Type:application/x-www-form-urlencoded" -X POST https://${VCO_IP_ADDRESS}:8283/j_security_check -d"j_username=${VCO_USERNAME}" -d"j_password=${VCO_PASSWORD}"
	echo " Login to ${VCO_IP_ADDRESS}"
}

exportconfig() {
	VCO_OUTPUT=/tmp/vco
	curl -s -o ${VCO_OUTPUT} -w "%{http_code} " -i -k -H "Content-Type:application/x-www-form-urlencoded" -b ${VCO_TEMP}/cookie -X GET https://${VCO_IP_ADDRESS}:8283/config_general/ExportConfig_export.action
	grep "/opt/vmo" ${VCO_OUTPUT} | sed "s/^[ \t]*//"	
}

initialLogin
exportconfig
