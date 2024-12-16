#!/bin/ash
# Author: William Lam
# Description: Create required partitions on single NVMe device for vSphere NVMe Tiering, ESXi-OSData and VMFS

# SSD Device Name (as shown in vdq -q)
SSD_DEVICE="t10.NVMe____Corsair_MP600_MICRO_____________________1203C06A94A77964"

# Size in GB for NVMe Tiering
NVME_TIERING_SIZE_IN_GB=256

# Size in GB for ESXi OSData
OSDATA_SIZE_IN_GB=32

# Name for VMFS datastore
VMFS_DATASTORE_NAME="local-vmfs-datastore"

### DO NOT EDIT BEYOND HERE ###

NVME_TIERING_GUID="B3676DDDA38A4CD6B970718D7F873811"
OSDATA_GUID="4EB2EA3978554790A79EFAE495E21F8D"
VMFS_GUID="AA31E02A400F11DB9590000C2911D1B8"

GREEN="\e[32m"
CYAN="\e[36m"
ENDCOLOR="\e[0m"

# Sector size in bytes
sector_size=512

# Start & End Sector for NVMe Tiering partition
nvme_start_sector=2048
nvme_end_sector=$(( (NVME_TIERING_SIZE_IN_GB * 1024 * 1024 * 1024 / sector_size ) - 1 ))

# Start & End Sector for ESXi OSData partition
osdata_partition_size_bytes=$(( (OSDATA_SIZE_IN_GB * 1024 * 1024 * 1024 / sector_size ) - 1 ))
osdata_start_sector=$(( nvme_end_sector + 1 ))
osdata_end_sector=$(( nvme_end_sector + osdata_partition_size_bytes ))

# Start & End Sector for VMFS partition
vmfs_start_sector=$(( osdata_end_sector + 1 ))
total_disk_capacity_bytes=$(partedUtil getUsableSectors /vmfs/devices/disks/${SSD_DEVICE} | awk '{print $2}')

# Construct partedUtil command
partedUtilCommand="partedUtil setptbl /vmfs/devices/disks/${SSD_DEVICE} gpt"

partition1="1 ${nvme_start_sector} ${nvme_end_sector} ${NVME_TIERING_GUID} 0"
partition2="2 ${osdata_start_sector} ${osdata_end_sector} ${OSDATA_GUID} 0"
partition3="3 ${vmfs_start_sector} ${total_disk_capacity_bytes} ${VMFS_GUID} 0"

echo -e "\n${GREEN}Running partedUtil command first:${ENDCOLOR}"
echo -e "${CYAN}${partedUtilCommand} \"${partition1}\" \"${partition2}\" \"${partition3}\"${ENDCOLOR}"
${partedUtilCommand} "${partition1}" "${partition2}" "${partition3}"

generated_uuid=$(python -c "import uuid; print(str(uuid.uuid4()))")
osdata_volume_name="OSDATA-${generated_uuid}"

echo -e "\n${GREEN}Running vmkfstools command second:${ENDCOLOR}"
echo -e "${CYAN}vmkfstools -C vmfs6l --isSystem 1 /vmfs/devices/disks/${SSD_DEVICE}:2 -S ${osdata_volume_name}${ENDCOLOR}"
vmkfstools -C vmfs6l --isSystem 1 /vmfs/devices/disks/${SSD_DEVICE}:2 -S ${osdata_volume_name}

system_generated_uuid=$(esxcli storage filesystem list | grep "${osdata_volume_name}" | awk '{print $3}')
new_osdata_volume_name="OSDATA-${system_generated_uuid}"

echo -e "\n${GREEN}Running ln command third:${ENDCOLOR}"
echo -e "${CYAN}ln -sf /vmfs/volumes/${system_generated_uuid} /vmfs/volumes/${new_osdata_volume_name}${ENDCOLOR}"
ln -sf /vmfs/volumes/${system_generated_uuid} /vmfs/volumes/${new_osdata_volume_name}

echo -e "\n${GREEN}Running vmkfstools command fourth:${ENDCOLOR}"
echo -e "${CYAN}vmkfstools -C vmfs6 /vmfs/devices/disks/${SSD_DEVICE}:3 -S ${VMFS_DATASTORE_NAME}${ENDCOLOR}"
vmkfstools -C vmfs6 /vmfs/devices/disks/${SSD_DEVICE}:3 -S ${VMFS_DATASTORE_NAME}

echo -e "\n${GREEN}Running vim-cmd command fifth:${ENDCOLOR}"
echo -e "${CYAN}vim-cmd hostsvc/advopt/update OSData.configuredLocation string /vmfs/volumes/${system_generated_uuid}${ENDCOLOR}\n"
vim-cmd hostsvc/advopt/update OSData.configuredLocation string /vmfs/volumes/${system_generated_uuid}