#!/bin/ash
# Author: William Lam
# Site: www.williamlam.com
# Description: Check the health of the installed media for ESXi

ESXI_BOOT_DEVICE_OUTPUT=/tmp/esxi_boot_device
NUMBER_OF_PASSES=3
CLEANUP=1

echo -e "\n\t#### Running ESXi boot device health verification ####\n"

echo "Retrieving ESXi boot device ..."
/bin/vmkfstools -P /bootbank > ${ESXI_BOOT_DEVICE_OUTPUT} 

ESXI_BOOT_DEVICE=$(awk '/Partitions spanned/{getline; print}' ${ESXI_BOOT_DEVICE_OUTPUT} | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
ESXI_BOOT_DEVICE=${ESXI_BOOT_DEVICE%:*}

echo "ESXi boot device is ${ESXI_BOOT_DEVICE}"
echo "Performing ${NUMBER_OF_PASSES} passes to verify health of ESXi Boot Device ..."
for i in $(seq 1 ${NUMBER_OF_PASSES})
do
	echo "Running pass ${i} ..."
	dd if=/dev/disks/${ESXI_BOOT_DEVICE} of=/tmp/esxi_boot_device.out bs=1M count=20; md5sum /tmp/esxi_boot_device.out > /tmp/esxi_boot_device_pass$i
done

echo "Calculating ESXi boot device health ..."
md5sum /tmp/esxi_boot_device_pass* | awk 'NR>1&&$1!=last{exit 1}{last=$1}' > /dev/null 2>&1
if [ $? -eq 0 ]; then
	echo "ESXi boot device is HEALTHY!"
else
	echo "**** ESXi boot device looks to be CORRUPTED, MD5 hashes do not match!!! ****"
fi

if [ ${CLEANUP} -eq 1 ]; then
	echo "Cleaning up temp files ..."
	rm -f ${ESXI_BOOT_DEVICE_OUTPUT}.out
	rm -f ${ESXI_BOOT_DEVICE_OUTPUT}_pass*
fi
