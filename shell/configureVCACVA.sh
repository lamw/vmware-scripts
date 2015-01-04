#!/bin/bash
# Author: William Lam
# Website: www.virtuallyghetto.com
# Product: VMware vCloud Automation Center
# Description: Script to automate the configuration of VCAC VA
# Reference: http://www.virtuallyghetto.com/2013/12/automating-vcac-vcloud-automation.html

VCAC_SSO_SERVER=vcac-id.primp-industries.com
VCAC_SSO_PASSWORD=VMware123!
VCAC_VA_HOSTNAME=vcac-va.primp-industries.com
NTP_SERVERS="172.30.0.100 172.30.0.101"
TIMEZONE=UTC
SSL_CERT_ORGANIZATION=primp-industries.com
SSL_CERT_ORGANIZATION_UNIT=skunkworks
SSL_CERT_COUNTRY=US
SSL_CERT_STATE=CA
SSl_CERT_CITY="Santa Barbara"
SSL_CERT_EMAIL=wlam@primp-industries.com
VCAC_LICENSE_KEY=12345678

### DO NOT EDIT BEYOND HERE ###

VCAC_CONFIG_LOG=vghetto-vcac-va.log
PRIVATE_KEY_FILE=server.key
CSR_FILE=server.csr
CERT_FILE=server.crt
PFX_FILE=server.p12

echo -e "\nConfiguring NTP Server(s) to ${NTP_SERVERS}  ..."
/usr/sbin/vcac-vami ntp use-ntp "${NTP_SERVERS}" >> "${VCAC_CONFIG_LOG}" 2>&1

echo "Configuring Timezone to ${TIMEZONE} ..."
/opt/vmware/share/vami/vami_set_timezone_cmd "${TIMEZONE}"

echo "Updating CAFE Hostname setting ..."
/usr/sbin/vcac-vami host update "${VCAC_VA_HOSTNAME}" >> "${VCAC_CONFIG_LOG}" 2>&1

echo "Generating Private Key ..."
/usr/bin/openssl genrsa -aes256 -passout 'pass:vmware123' -out "${PRIVATE_KEY_FILE}" 2048 >> "${VCAC_CONFIG_LOG}" 2>&1

echo "Generating CSR ..."
/usr/bin/openssl req -new -key "${PRIVATE_KEY_FILE}" -out "${CSR_FILE}" -passin 'pass:vmware123' -utf8 -subj "/C=${SSL_CERT_COUNTRY}/ST=${SSL_CERT_STATE}/L=${SSl_CERT_CITY}/O=${SSL_CERT_ORGANIZATION}/OU=${SSL_CERT_ORGANIZATION_UNIT}/CN=${VCAC_VA_HOSTNAME}/emailAddress=${SSL_CERT_EMAIL}" >> "${VCAC_CONFIG_LOG}" 2>&1

echo "Removing passphrase from Private Key ..."
/bin/cp "${PRIVATE_KEY_FILE}" "${PRIVATE_KEY_FILE}.org" >> "${VCAC_CONFIG_LOG}" 2>&1
/usr/bin/openssl rsa -in "${PRIVATE_KEY_FILE}.org" -out "${PRIVATE_KEY_FILE}" -passin 'pass:vmware123' >> "${VCAC_CONFIG_LOG}" 2>&1

echo "Generate Self-Signed Certificate ..."
/usr/bin/openssl x509 -req -days 365 -in "${CSR_FILE}" -signkey "${PRIVATE_KEY_FILE}" -out "${CERT_FILE}" >> "${VCAC_CONFIG_LOG}" 2>&1

echo "Creating PEM file for Apache Server ..."
/bin/cat "${CERT_FILE}" "${PRIVATE_KEY_FILE}" > /etc/apache2/server.pem

echo "Importing SSL Certificate into VCAC Keystore ..."
/usr/bin/openssl pkcs12 -export -passout 'pass:vmware123' -in "${CERT_FILE}" -inkey "${PRIVATE_KEY_FILE}" -out "${PFX_FILE}" -name apache >> "${VCAC_CONFIG_LOG}" 2>&1
/usr/java/jre-vmware/bin/keytool -importkeystore -deststorepass password -destkeystore /etc/vcac/vcac.keystore -srckeystore "${PFX_FILE}" -srcstoretype PKCS12 -srcstorepass 'vmware123' -srcalias apache -destalias apache >> "${VCAC_CONFIG_LOG}" 2>&1

echo "Importing vCAC Identity SSL Certificate (websso) ..."
/usr/sbin/vcac-config import-certificate --alias websso --url "https://${VCAC_SSO_SERVER}:7444" >> "${VCAC_CONFIG_LOG}" 2>&1

echo "Starting Apache Server ..."
/etc/init.d/apache2 restart >> "${VCAC_CONFIG_LOG}" 2>&1

echo "Registering SSO Server ..."
/usr/sbin/vcac-config sso-update --vcac-host "${VCAC_VA_HOSTNAME}" --sso-host "${VCAC_SSO_SERVER}:7444" --tenant vsphere.local --user administrator@vsphere.local --password "${VCAC_SSO_PASSWORD}" >> "${VCAC_CONFIG_LOG}" 2>&1

echo "Starting vCAC Server ..."
/etc/init.d/vcac-server restart >> "${VCAC_CONFIG_LOG}" 2>&1

echo "Starting VCO Server ..."
/etc/init.d/vco-server restart >> "${VCAC_CONFIG_LOG}" 2>&1

echo "Waiting 5 minutes for VCAC services to startup ..."
sleep 300

echo -e "Adding vCAC License ...\n"
/usr/sbin/vcac-config license-update --key "${VCAC_LICENSE_KEY}" >> "${VCAC_CONFIG_LOG}" 2>&1
