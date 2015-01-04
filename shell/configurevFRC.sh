#!/bin/ash
# Author: William Lam
# Website: www.virtuallyghetto.com
# Product: VMware ESXi & vFRC
# Description: Automating vFRC Configurations in ESXi
# Reference: http://www.virtuallyghetto.com/2013/11/how-to-automate-configuration-of-vfrc.html

IFS=$'\n'
FIRST_VFFS_DEVICE=""
COUNT=0
for DEVICE_ID in $(esxcli storage vflash device list | grep "Yes, this is a blank disk." | awk '{print $1}');
do
	DEVICE="/vmfs/devices/disks/${DEVICE_ID}"
	echo "Creating partition for ${DEVICE} ..."
	END_SECTOR=$(eval expr $(partedUtil getptbl ${DEVICE} | tail -1 | awk '{print $1 " \\* " $2 " \\* " $3}') - 1)
	/sbin/partedUtil "setptbl" "${DEVICE}" "gpt" "1 2048 ${END_SECTOR} AA31E02A400F11DB9590000C2911D1B8 0" > /dev/null 2>&1
	if [ ${COUNT} -eq 0 ]; then
		echo "Primary paritition for VFFS will be ${DEVICE}"
		FIRST_VFFS_DEVICE=${DEVICE}
	fi
	COUNT=$((COUNT+1))
done

echo "Creating VFFS on ${FIRST_VFFS_DEVICE} ..."
vmkfstools -C vmfsl ${FIRST_VFFS_DEVICE}:1 -S vffs-$(hostname -s) > /dev/null 2>&1

echo "Creating answer file under /tmp/answer"
echo "0" > /tmp/answer

IFS=$'\n'
for DEVICE_ID in $(esxcli storage vflash device list | grep naa | awk '{print $1}');
do
        DEVICE="/vmfs/devices/disks/${DEVICE_ID}"
	if [ "${DEVICE}" != "${FIRST_VFFS_DEVICE}" ]; then
		echo "Extending VFFS (${FIRST_VFFS_DEVICE}) with ${DEVICE}"
		vmkfstools -Z ${DEVICE}:1 ${FIRST_VFFS_DEVICE}:1 < /tmp/answer > /dev/null 2>&1
	fi    
done

echo "Refreshing ESXi storage sub-system ..."
vim-cmd hostsvc/storage/refresh 

echo "Adding Virtual Flash Resource using vSphere MOB ..."
VFFS_UUID=$(vmkfstools -Ph /vmfs/volumes/vffs-$(hostname -s) | grep UUID | awk -F ": " '{print $2}')
python addVirtualFlashResource.py ${VFFS_UUID}
