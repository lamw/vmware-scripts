#!/bin/bash
# William Lam
# http://blogs.vmware.com/vsphere/automation/

PASSWORD=

if [[ $# -ne 3 ]]; then
	echo -e "\nUsage: $0 [USERNAME] [HOSTLIST] [SYSLOG_SERVERS]\n"
	exit 1
fi

if [ -z ${PASSWORD} ]; then
	echo -e "You forgot to set the password in the script!\n"
	exit 1
fi

USERNAME=$1
INPUT=$2
SYSLOG=$3

for HOST in $(cat ${INPUT});
do
	echo "Configuring syslog server for ${HOST} ..."
	esxcli --server ${HOST} --username ${USERNAME} --password ${PASSWORD} network firewall ruleset set --enabled yes --ruleset-id syslog
	esxcli --server ${HOST} --username ${USERNAME} --password ${PASSWORD} system syslog config set --loghost "${SYSLOG}"
	esxcli --server ${HOST} --username ${USERNAME} --password ${PASSWORD} system syslog reload
done
