#!/bin/bash
# William Lam
# http://www.virtuallyghetto.com/

if [ $# -ne 3 ]; then
	echo "Usage: $0 USERNAME@ORGANIZATION PASSWORD VCD-FQDN"
	echo -e "\n\t$0 'coke-admin@Coke' 'vmware' 'vcd.primp-industries.com'\n"
	exit 1;
fi

USER=$1
PASS=$2 
VCDHOST=$3
RESPONSE_OUT=/tmp/out

#login
curl -i -k -H "Accept:application/*+xml;version=1.5" -u "${USER}:${PASS}" -X POST "https://${VCDHOST}/api/sessions" -s 0 -o ${RESPONSE_OUT}

grep "200 OK" ${RESPONSE_OUT} > /dev/null 2>&1
if [ $? -eq 0 ]; then
	echo "Successfully logged into ${VCDHOST}"
	VCD_AUTHTOKEN=$(grep x-vcloud-authorization ${RESPONSE_OUT})

	# query VMs
	curl -i -k -H "Accept:application/*+xml;version=1.5" -H "${VCD_AUTHTOKEN}" -X GET "https://${VCDHOST}/api/query?type=vm&filter=status==POWERED_ON&fields=name,containerName" -s 0

	echo -e "\nPlease provide the VM href you wish to retrieve Remote Console Screen Ticket: "
	read -e VM

	# retrieve screenticket
	VM_TICKET=$(curl -i -k -H "Accept:application/*+xml;version=1.5" -H "${VCD_AUTHTOKEN}" -X POST "${VM}/screen/action/acquireTicket" -s 0 | awk -F'[<|>]' '/ScreenTicket/{print $3}' |  perl -lpi -MURI::Escape -e '$_ = uri_escape($_)')

	echo -e "\nhttp://air.primp-industries.com/vmrc/console.html?${VM_TICKET}"	

	# logout
	curl -i -k -H "Accept:application/*+xml;version=1.5" -H "${VCD_AUTHTOKEN}" -X DELETE "https://${VCDHOST}/api/session" -s0 -o ${RESPONSE_OUT}
	grep " 204 No Content" ${RESPONSE_OUT} > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo -e "\nSuccesfully logged out"
	fi
else 
	echo "Unable to login, please verify your input!"
fi

rm -rf ${RESPONSE_OUT}
