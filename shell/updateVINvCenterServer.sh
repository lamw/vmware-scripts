#!/bin/bash
# Author: William Lam
# Website: www.williamlam.com
# Product: VMware Infrastructure Navigator
# Description: Extracting info from VIN
# Reference: http://www.williamlam.com/2012/11/extracting-information-from-vin-vsphere_6.html

VC_URL=https://vcsa.primp-industries.com/vsm/extensionService
VC_TOKEN=f21aa9f61d3d3604ded8b5c8872eb4d581a07e32
VC_THUMBPRINT=ed:76:70:ab:0c:86:ef:81:4c:04:7a:5c:98:6b:e4:4b:ad:c5:81:e4
VC_IP=172.30.0.238
VC_ADDRESS=vcsa.primp-industries.com

## DO NOT MODIFY BEYOND HERE ##

OVF_CONF=/opt/vmware/etc/vami/ovfEnv.xml
URL_ESCAPE=$(echo ${VC_URL} | sed -e 's/[\/&]/\\&/g')

echo "Updating vCenter Server Ext Service URL ..."
sed -i "s/<evs:URL>.*/<evs:URL>${URL_ESCAPE}<\/evs:URL>/g" ${OVF_CONF}
echo "Updating vCenter Server Token ..."
sed -i "s/<evs:Token>.*/<evs:Token>${VC_TOKEN}<\/evs:Token>/g" ${OVF_CONF}
echo "Updating vCenter Server Thumbprint ..."
sed -i "s/<evs:X509Thumbprint>.*/<evs:X509Thumbprint>${VC_THUMBPRINT}<\/evs:X509Thumbprint>/g" ${OVF_CONF}
echo "Updating vCenter Server IP & Address ..."
sed -i "s/<evs:IP>.*/<evs:IP>${VC_IP}<\/evs:IP>/g" ${OVF_CONF}
sed -i "s/<evs:Address>.*/<evs:Address>${VC_ADDRESS}<\/evs:Address>/g" ${OVF_CONF}

