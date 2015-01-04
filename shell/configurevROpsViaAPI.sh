#!/bin/bash
# Author: William Lam
# Website: www.virtuallyghetto.com
# Product: VMware vRealize Operations Manager 6.0
# Description: Initial Configuration of vRealize Operations Manager 6.0 using vROps CaSA REST API
# Reference: http://www.virtuallyghetto.com/2014/12/automating-deployment-configuration-of-vrealize-operations-manager-6-0-part-3.html

VROPS_IP_ADDRESS=192.168.1.150
VROPS_USERNAME=admin
VROPS_PASSWORD=VMware1!
VROPS_CLUSTER_NAME=vrops-cluster
VROPS_SLICE_NAME=vrops-slice-1
NTP_SERVER=1.pool.ntp.org

### DO NOT EDIT PASS THIS ###

VROPS_TEMP=/tmp/vrops-config-$$
mkdir -p ${VROPS_TEMP}

setIntialAdminPassword() {
	ADMIN_PASS_BODY=${VROPS_TEMP}/adminpass-body 

	cat > ${ADMIN_PASS_BODY} << __ADMIN_PASS__
{"password":"${VROPS_PASSWORD}"}
__ADMIN_PASS__

	echo -e "\nConfiguring vROps Admin password ..."
	curl -s -o /dev/null -w "%{http_code}" -i -k -H "Content-Type:application/json" -d@${ADMIN_PASS_BODY} -X PUT https://${VROPS_IP_ADDRESS}/casa/security/adminpassword/initial
}

configureNTP() {
	NTP_BODY=${VROPS_TEMP}/ntp-body

	cat > ${NTP_BODY} << __NTP_BODY__
{"time_servers": [{"address": "${NTP_SERVER}"}]}}
__NTP_BODY__

	echo -e "\nConfiguring NTP Servers ..."
	curl -s -o /dev/null -w "%{http_code}" -i -k -H "Content-Type:application/json" -d@${NTP_BODY} -u "${VROPS_USERNAME}:${VROPS_PASSWORD}" -b ${VROPS_TEMP}/cookie -X POST https://${VROPS_IP_ADDRESS}/casa/sysadmin/cluster/ntp
}

configureRole() {
	ROLE_BODY=${VROPS_TEMP}/role-body

	cat > ${ROLE_BODY} << __ROLE_BODY__
[
  {
    "slice_address": "${VROPS_IP_ADDRESS}",
    "admin_slice": "${VROPS_IP_ADDRESS}",
    "is_ha_enabled": false,
    "user_id":"admin",
    "password":"${VROPS_PASSWORD}",
    "slice_roles": [
      "ADMIN",
      "DATA",
      "UI"
    ]
  }
]
__ROLE_BODY__

	echo -e "\nConfiguring vROps Cluster Role ..."
	curl -s -o /dev/null -w "%{http_code}" -i -k -H "Content-Type:application/json" -d@${ROLE_BODY} -u "${VROPS_USERNAME}:${VROPS_PASSWORD}" -b ${VROPS_TEMP}/cookie -X POST https://${VROPS_IP_ADDRESS}/casa/deployment/slice/role
	echo -e "\nSleeping for 300 seconds for configuration changes to be applied ..."
	sleep 300
}

configureClusterName() {
	CLUSTER_BODY=${VROPS_TEMP}/cluster-body

	cat > ${CLUSTER_BODY} << __CLUSTER_BODY__
{"cluster_name":"${VROPS_CLUSTER_NAME}"}
__CLUSTER_BODY__

	echo -e "\nConfiguring vROps Cluster Name to ${VROPS_CLUSTER_NAME} ..."
	curl -s -o /dev/null -w "%{http_code}" -i -k -H "Content-Type:application/json" -d@${CLUSTER_BODY} -u "${VROPS_USERNAME}:${VROPS_PASSWORD}" -b ${VROPS_TEMP}/cookie -X PUT https://${VROPS_IP_ADDRESS}/casa/deployment/cluster/info
}

configureSliceName() {
	SLICE_BODY=${VROPS_TEMP}/slice-body

	cat > ${SLICE_BODY} << __SLICE_BODY__
{"slice_name":"${VROPS_SLICE_NAME}"}
__SLICE_BODY__

	echo -e "\nConfiguring vROps Slice Name to ${VROPS_SLICE_NAME} ..."
	curl -s -o /dev/null -w "%{http_code}" -i -k -H "Content-Type:application/json" -d@${SLICE_BODY} -u "${VROPS_USERNAME}:${VROPS_PASSWORD}" -b ${VROPS_TEMP}/cookie -X PUT https://${VROPS_IP_ADDRESS}/casa/deployment/slice/${VROPS_IP_ADDRESS}
}

initializeCluster() {
	INIT_BODY=${VROPS_TEMP}/init-body

	cat > ${INIT_BODY} << __INIT_BODY__
{"online_state": "ONLINE","online_state_reason": "Init via vGhetto Script"}
__INIT_BODY__

	echo -e "\nInitializing vROps Cluster ..."
	curl -s -o /dev/null -w "%{http_code}" -i -k -H "Content-Type:application/json" -u "${VROPS_USERNAME}:${VROPS_PASSWORD}" -b ${VROPS_TEMP}/cookie -X POST https://${VROPS_IP_ADDRESS}/casa/deployment/cluster/initialization?async=true
	echo -e "\nOnlining the vROps Cluster ..."
	curl -s -o /dev/null -w "%{http_code}" -i -k -H "Content-Type:application/json" -d@${INIT_BODY} -u "${VROPS_USERNAME}:${VROPS_PASSWORD}" -b ${VROPS_TEMP}/cookie -X POST https://${VROPS_IP_ADDRESS}/casa/sysadmin/cluster/online_state?async=true

	echo -e "\nYou will need to wait a few minutes for the vROps Cluster to be ready for login. Automatic re-direction to https://${VROPS_IP_ADDRESS}/vcops-web-ent should happen when specifying the IP Address/Hostname of vROps in the browser"
}

setIntialAdminPassword
configureNTP
configureRole
configureClusterName
configureSliceName
initializeCluster

rm -rf ${VROPS_TEMP}
