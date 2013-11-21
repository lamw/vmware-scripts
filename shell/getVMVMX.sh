#!/bin/bash
# William Lam
# http://www.virtuallyghetto.com/
# Script leveraging vifs to download .vmx configuration files

if [[ $# -ne 5 ]] && [[ $# -ne 6 ]]; then
	echo "[Usage] $0 ESXI_HOSTNAME USERNAME PASSWORD DATASTORE OPERATION [DIR]"
	echo -e "\n\t$0 himalaya.primp-industries.com root \"mySuperSecurePassword\" datastore01 list"
	echo -e "\t$0 himalaya.primp-industries.com root \"mySuperSecurePassword\" datastore01 download myvmx_files"
	exit 1
fi

SERVER=$1
USERNAME=$2
PASSWORD=$3
DATASTORE=$4
OP=$5
DIR=$6

if [ ${OP} == "download" ]; then
	mkdir -p "${DIR}"
fi

IFS=$'\n'
for VMDIR in $(vifs --server ${SERVER} --username ${USERNAME} --password ${PASSWORD} -D "[${DATASTORE}]" | grep -vE '(---|Content Listing)')
do
	VMPATH="[${DATASTORE}] ${VMDIR}"
	for VMX in $(vifs --server ${SERVER} --username ${USERNAME} --password ${PASSWORD} -D "${VMPATH}" | grep -vE '(---|Content Listing)' | grep ".vmx$")
	do
		VMXPATH="${VMPATH}${VMX}"
		if [ ${OP} == "download" ]; then
			vifs --server ${SERVER} --username ${USERNAME} --password ${PASSWORD} -g "${VMXPATH}" "${DIR}/${VMX}"
		else 
			echo ${VMXPATH}
		fi
	done
done
