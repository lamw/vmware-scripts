#!/bin/ash
# William Lam
# http://www.virtuallyghetto.com/

VPXA_CONFIG=/etc/opt/vmware/vpxa/vpxa.cfg

grep "outputToSyslog" "${VPXA_CONFIG}" > /dev/null 2>&1
if [ $? -eq 1 ]; then
	echo "Updating ${VPXA_CONFIG} with Syslog fix for vpxa ..."
	sed -ie 's|<\/outputToConsole>|<\/outputToConsole>\n    <outputToSyslog>true<\/outputToSyslog>\n    <syslog>\n\t<ident>vpxa<\/ident>\n\t<facility>local4<\/facility>\n    <\/syslog>|g' "${VPXA_CONFIG}" > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo -e "Changes were successful, backing up configuration to local bootbank\n"
		/sbin/auto-backup.sh
		echo -e "\nPlease reboot your host for changes to take effect!"
	fi
fi
