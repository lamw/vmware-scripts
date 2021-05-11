#!/bin/ash
# Author: William Lam
# Website: www.williamlam.com
# Product: VMware ESXi
# Description: Update syslog tweak for ESXi
# Reference: http://www.williamlam.com/2010/06/esxi-syslog-caveat.html

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
