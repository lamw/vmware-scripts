#!/bin/bash
# Author: William Lam
# Website: www.williamlam.com
# Product: VMware ESXi
# Description: Automate disabling of VAAI UMAP on ESXi
# Reference: http://www.williamlam.com/2011/10/how-to-automate-disabling-of-vaai-unmap.html

if [ $# -ne 4 ]; then
	echo "Usage: $0 [HOST_LIST] [VCENTER_SERVER] [VCENTER_AUTH_CONFIG] [1|0]"
	exit 1;
fi

ESXI_LIST=$1
VCENTER_SERVER=$2
VCENTER_AUTH=$3
OP_FLAG=$4

for ESXIHOST in $(cat ${ESXI_LIST});
do
	if [ ${OP_FLAG} -eq 1 ]; then
		OPERATION="enabling"
	else 
		OPERATION="disabling"
	fi
	echo "${OPERATION} VAAI UNMAP primitve on ${ESXIHOST}"
	esxcli --server ${VCENTER_SERVER} --config ${VCENTER_AUTH} --vihost ${ESXIHOST} system settings advanced set --int-value ${OP_FLAG} --option /VMFS3/EnableBlockDelete
done
