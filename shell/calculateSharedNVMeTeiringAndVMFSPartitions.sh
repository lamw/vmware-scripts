#!/bin/ash
# Author: William Lam
# Description: Generate the required partedUtil commands to use single NVMe devie for vSphere NVMe Tiering and VMFS

# SSD Device Name (as shown in vdq -q)
SSD_DEVICE="t10.NVMe____Corsair_MP600_MICRO_____________________1203C06A94A77964"

# Size in GB for NVMe Tiering
NVME_TIERING_SIZE_IN_GB=256

VMFS_DATASTORE_NAME="local-vmfs-datastore"

### DO NOT EDIT BEYOND HERE ###

NVME_TIERING_GUID="B3676DDDA38A4CD6B970718D7F873811"
VMFS_GUID="AA31E02A400F11DB9590000C2911D1B8"

GREEN="\e[32m"
CYAN="\e[36m"
ENDCOLOR="\e[0m"

# Sector size in bytes
sector_size=512

# Start & End Sector for NVMe Tiering partition
nvme_start_sector=2048
nvme_end_sector=$(( (NVME_TIERING_SIZE_IN_GB * 1024 * 1024 * 1024 / sector_size ) - 1 ))

# Start & End Sector for VMFS partition
vmfs_start_sector=$(( nvme_end_sector + 1 ))
total_disk_capacity_bytes=$(partedUtil getUsableSectors /vmfs/devices/disks/${SSD_DEVICE} | awk '{print $2}')

# Construct partedUtil command
partedUtilCommand="partedUtil setptbl /vmfs/devices/disks/${SSD_DEVICE} gpt"

partition1="1 ${nvme_start_sector} ${nvme_end_sector} ${NVME_TIERING_GUID} 0"
partition2="2 ${vmfs_start_sector} ${total_disk_capacity_bytes} ${VMFS_GUID} 0"

echo -e "\n${GREEN}Generated partedUtil command to run first:${ENDCOLOR}"
echo -e "${CYAN}${partedUtilCommand} \"${partition1}\" \"${partition2}\"${ENDCOLOR}"

echo -e "\n${GREEN}Generated vmkfstools command to run second:${ENDCOLOR}"
echo -e "${CYAN}vmkfstools -C vmfs6 /vmfs/devices/disks/${SSD_DEVICE}:2 -S ${VMFS_DATASTORE_NAME}${ENDCOLOR}\n"