#!/bin/ash
# Author: William Lam
# Website: www.virtuallyghetto.com
# Product: VMware ESXi
# Description: Enabling management traffic type on ESXI
# Reference: http://www.virtuallyghetto.com/2011/02/another-way-to-enable-management.html

if [ $# -ne 1 ]; then
        echo "Usage: $0 [VMK_INTERFACE]"
        echo -e "\n\t$0 vmk1"
        exit 1
fi

VMK_INT=$1
HOSTSVC_FILE=/etc/vmware/hostd/hostsvc.xml

grep ${VMK_INT} ${HOSTSVC_FILE} > /dev/null 2>&1
if [ $? -eq 0 ]; then
        echo "VMkernel interface: ${VMK_INT} is already enabled with managment traffic!"
        exit 1
fi

echo -e "Enabling VMkernel interface: ${VMK_INT} with management traffic type ...\n"
CURRENT_NIC_ID=$(sed -n '/mangementVnics/,/mangementVnics/p' ${HOSTSVC_FILE} | grep vmk | sed 's/.*"\(.*\)"[^"]*$/\1/' | sort -n | tail -1)
CURRENT_NIC_PLUS_ONE_ID=$((CURRENT_NIC_ID+1))
NEXT_NIC_ID=$(printf "%04d" ${CURRENT_NIC_PLUS_ONE_ID})
sed -i "/id=\"${CURRENT_NIC_ID}\"/a  <nic id=\"${NEXT_NIC_ID}\">${VMK_INT}</nic>" ${HOSTSVC_FILE}
echo -e "Restarting hostd ...\n"
/etc/init.d/hostd restart
echo -e "Sleeping for 5secs while hostd reloads ...\n"
sleep 5
echo -e "Refreshing the network sub-sys ...\n"
vim-cmd hostsvc/net/refresh
