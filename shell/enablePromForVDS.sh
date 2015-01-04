#!/bin/bash
# Author: William Lam
# Website: www.virtuallyghetto.com
# Product: VMware vCloud Director
# Description: Shell script to enable promiscuous & forged transmit mode for VDS in VCNS
# Reference: http://www.virtuallyghetto.com/2013/05/how-to-enable-nested-esxi-using-vxlan.html

if [ $# -ne 3 ] ;then
	echo -e "\nUsage: $0 VCNS_IP VDS_MOREF VDS_MTU"
	echo -e "\n   $0 172.30.0.196 dvs-13 9000\n"
	exit 1
fi

VCNS_IP=$1
VDS_MOREF=$2
VDS_MTU=$3

VCNS_USERNAME=admin
VCNS_PASSWORD=default
VCNS_INPUT_FILE=/tmp/enable-vds-prom

cat > ${VCNS_INPUT_FILE} << __PREPARE_VDS__
<vdsContext>
  <switch>
    <objectId>${VDS_MOREF}</objectId>
  </switch>
  <mtu>${VDS_MTU}</mtu>
  <promiscuousMode>true</promiscuousMode>
</vdsContext>
__PREPARE_VDS__

echo "Preparing VDS ${VDS_MOREF} with MTU ${VDS_MTU} on VCNS ${VCNS_IP} ..."
curl -i -k -H "Content-Type: application/xml" -u "${VCNS_USERNAME}:${VCNS_PASSWORD}" -d @${VCNS_INPUT_FILE} -X POST "https://${VCNS_IP}/api/2.0/vdn/switches"
