#!/bin/ash
# Author: William Lam
# Website: www.virtuallyghetto.com
# Product: VMware ESXi
# Description: Automate space reclaimation on ESXi
# Reference: http://www.virtuallyghetto.com/2012/03/automating-dead-space-reclamation-in.html

if [[ $# -ne 1 ]] && [[ $# -ne 2 ]]; then
	echo -e "\nUsage: $0 PERCENTAGE_RECLAIM [DATASTORE_LIST]"
	echo -e "\n\t$0 60"
	echo -e "\t$0 60 datastore_list.txt\n"
	exit 1;
fi

PERCENTAGE_RECLAIM=$1
DATASTORE_LIST=$2

# validate % reclaim
if [[ ${PERCENTAGE_RECLAIM} -le 0 ]] || [[ ${PERCENTAGE_RECLAIM} -ge 100 ]]; then
	echo "Percentage reclaim must be between 0-100"
	exit 1;
fi

ESXI_VERSION=$(/bin/vmware -l)

# ensure we're running ESXi 5.0u1
if [ "${ESXI_VERSION}" != "VMware ESXi 5.0.0 Update 1" ]; then
	echo "Dead Space Reclaimation feature is only available with ESXi 5.0 Update 1"
	exit 1;
fi

# ensure host is in maint mode
/bin/vim-cmd hostsvc/runtimeinfo | grep -i inMaintenanceMode | grep true > /dev/null 2>&1
if [ $? -eq 1 ]; then
	echo "Please put host into maintenance mode before running this script"
	exit 1;
fi

#do VMware magic
if [[ $# -eq 2 ]] && [[ -f ${DATASTORE_LIST} ]]; then 
	IFS='
'
	for VMFS_DATASTORE in $(cat ${DATASTORE_LIST});
	do
		VMFS_DIRECTORY="/vmfs/volumes/${VMFS_DATASTORE}"
		if [ -L ${VMFS_DIRECTORY} ]; then
			#change into the VMFS volume directory, this is needed to perform operation
			cd ${VMFS_DIRECTORY}
			
			#run vmkfstools -y %
			/sbin/vmkfstools -y ${PERCENTAGE_RECLAIM}

			#change back out to /
			cd /
		fi
	done
	unset IFS
else 
	for VMFS_DIRECTORY in $(/sbin/esxcli storage filesystem list | grep -E '(VMFS-3|VMFS-5)' | awk '{print $1}');
	do
		#change into the VMFS volume directory, this is needed to perform operation
		cd ${VMFS_DIRECTORY}
	
		#run vmkfstools -y %
		/sbin/vmkfstools -y ${PERCENTAGE_RECLAIM}

		#change back out to /
		cd /	
	done
fi
