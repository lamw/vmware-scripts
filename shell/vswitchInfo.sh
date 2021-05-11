# Author: William Lam
# Website: www.williamlam.com
# Product: VMware ESXi
# Description: Query MACs on internal vSwitch
# Reference: http://www.williamlam.com/2011/05/how-to-query-for-macs-on-internal.html

if [[ $# -ne 1 ]] && [[ $# -ne 4 ]]; then
        echo -e "Usage: $0 -l -v [vSWITCH] -p [PORT]\n"
        echo "  -l List all ports of vSwitch(s)"
        echo "  -v vSwitch to query"
        echo "  -p Port to query on vSwitch"
        echo -e "\n\t$0 -l"
        echo -e "\t$0 -v vSwitch0 -p 1234\n"
        exit 0
fi

if [ ! -e /sbin/vsish ]; then
	echo "Script is only supported running on an ESXi host as vsish is not available by default on ESX"
	exit 1
fi

VSISH_VSWITCH_PATH=/net/portsets

if [ $# -eq 1 ]; then
        for vSwitch in $(vsish -e ls ${VSISH_VSWITCH_PATH});
        do
        	VSWITCH=$(echo ${vSwitch} | sed 's/\///g')
                for port in $(vsish -e ls ${VSISH_VSWITCH_PATH}/${vSwitch}ports);
                do
                	PORT=$(echo ${port} | sed 's/\///g')
                        PORTINFO=$(vsish -e get ${VSISH_VSWITCH_PATH}/${vSwitch}ports/${port}status | sed 's/^[ \t]*//;s/[ \t]*$//');
                        CLIENT=$(echo ${PORTINFO} | sed 's/ /\n/g' | grep "clientName:" | awk -F ":" '{print $2}')
			MACADDRESS=$(echo ${PORTINFO} | sed 's/ /\n/g' | grep "unicastAddr:" | uniq | sed 's/unicastAddr://;s/\(.*\)./\1/')
                       	echo -e "${VSWITCH}\t${PORT}\t${MACADDRESS%%::*}\t${CLIENT}"
                done
        done
fi

if [ $# -eq 4 ]; then
        QUERY_PATH="${VSISH_VSWITCH_PATH}/${2}/ports/${4}/status"
        echo "Querying port path: ${QUERY_PATH}"
        PNICS=$(vsish -e ls /net/portsets/${2}/uplinks/ | sed '$!N;s/\n/ /;s/\///g')
        echo -e "pNICS for vSwitch: ${PNICS}\n"
        vsish -e get "${QUERY_PATH}"
fi
