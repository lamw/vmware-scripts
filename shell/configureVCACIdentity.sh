#!/bin/bash
# William lam
# www.virtuallyghetto.com
# Script to automatically configure the VCAC Identity VA (SSO)

VCAC_SSO_PASSWORD=VMware123!
VCAC_SSO_HOSTNAME=vcac-id.primp-industries.com
TIMEZONE=UTC
NTP_SERVERS="172.30.0.100 172.30.0.101"
JOIN_AD=0
AD_DOMAIN=primp-industries.com
AD_USERNAME=username
AD_PASSWORD=superdupersecretpassword

### DO NOT EDIT BEYOND HERE ###

VCAC_CONFIG_LOG=vghetto-vcac-id.log

echo -e "\nConfiguring NTP Server(s) to ${NTP_SERVERS}  ..."
/opt/vmware/share/vami/custom-services/bin/vami ntp use-ntp "${NTP_SERVERS}" >> "${VCAC_CONFIG_LOG}" 2>&1

echo "Configuring Timezone to ${TIMEZONE} ..."
/opt/vmware/share/vami/vami_set_timezone_cmd "${TIMEZONE}" >> "${VCAC_CONFIG_LOG}" 2>&1

echo "Configuring SSO ..."
/usr/lib/vmware-identity-va-mgmt/firstboot/vmware-identity-va-firstboot.sh --domain vsphere.local --password "${VCAC_SSO_PASSWORD}"

echo "${VCAC_SSO_HOSTNAME}:7444" > /etc/vmware-identity/hostname.txt

if [ ${JOIN_AD} -eq 1 ]; then 
	echo "${AD_PASSWORD}" > /tmp/ad-pass

	echo "Joining AD Domain ${AD_DOMAIN}"
	/opt/likewise/bin/domainjoin-cli join "${AD_DOMAIN}" "${AD_USERNAME}" < /tmp/ad-pass 

	rm -f /tmp/ad-pass
fi

echo 
