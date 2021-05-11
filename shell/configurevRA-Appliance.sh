#!/bin/bash
# Author: William Lam
# Site: www.williamlam.com
# Description: Script to configure vRA 7 Appliance
# Reference: http://www.williamlam.com/2016/02/automating-vrealize-automation-7-simple-minimal-part-3-vra-appliance-configuration.html

# SSO Password
HORIZON_SSO_PASSWORD='VMware1!'
# NTP Server
NTP_SERVER=""
# vRA License key (optional)
VRA_LICENSE_KEY=""

#########  Optional #########

VRA_SSL_CERT_COUNTRY="US"
VRA_SSL_CERT_STATE="CA"
VRA_SSL_CERT_ORG="Primp-Industries"
VRA_SSL_CERT_ORG_UNIT='R&D'

######### DO NOT EDIT BEYOND HERE #########

VRA_INSTALL_LOG=/var/log/vra-appliance-configuration.log
CERTS_FOLDER="/root/certs"
VRA_APPLIANCE_HOSTNAME=$(hostname)

if [[ -z "${NTP_SERVER}" ]] || [[ -z "${HORIZON_SSO_PASSWORD}" ]]; then
  echo "Please ensure you set both an NTP Server and Horizon SSO Password before running the script"
  exit 1
fi

echo "Installation logs will be stored at ${VRA_INSTALL_LOG}"

echo "Configuring NTP ..."
echo "server ${NTP_SERVER}" >> /etc/ntp.conf
/etc/init.d/ntp restart >> "${VRA_INSTALL_LOG}" 2>&1
sntp "${NTP_SERVER}" >> "${VRA_INSTALL_LOG}" 2>&1

echo "Configuring vRA Appliance hostname: "
/usr/sbin/vcac-vami host update ${VRA_APPLIANCE_HOSTNAME} >> "${VRA_INSTALL_LOG}" 2>&1
sed -i "s/vmidentity.websso.host=.*$/vmidentity.websso.host=${VRA_APPLIANCE_HOSTNAME}/g" /etc/vcac/security.properties

echo "Generating vRA Appliance SSL Certificate"
mkdir -p "${CERTS_FOLDER}"
/usr/sbin/vcac-vami certificate-generate -k "${CERTS_FOLDER}/vamicert.key" -p "${CERTS_FOLDER}/vamicert.crt" -n "${VRA_APPLIANCE_HOSTNAME}" -c "${VRA_SSL_CERT_COUNTRY}" -s "${VRA_SSL_CERT_STATE}" -o "${VRA_SSL_CERT_ORG}" -u "${VRA_SSL_CERT_ORG_UNIT}" >> "${VRA_INSTALL_LOG}" 2>&1
cat "${CERTS_FOLDER}/vamicert.key" "${CERTS_FOLDER}/vamicert.crt" > "${CERTS_FOLDER}/vamicert.pem"

echo "Importing newly created vRA Appliance SSL Certificate ..."
/usr/sbin/vcac-config -v certificate-import --encodedCertificate "${CERTS_FOLDER}/vamicert.pem" --encodedKey "${CERTS_FOLDER}/vamicert.key" >> "${VRA_INSTALL_LOG}" 2>&1
/etc/init.d/haproxy restart >> "${VRA_INSTALL_LOG}" 2>&1

echo "Configuring Horizon SSO ..."
/usr/sbin/activate-sso horizon >> "${VRA_INSTALL_LOG}" 2>&1
/usr/sbin/vcac-vami horizon-conf "${HORIZON_SSO_PASSWORD}" >> "${VRA_INSTALL_LOG}" 2>&1
sleep 10

echo "Starting vPostgres DB setup ..."
/usr/sbin/vcac-vami db-upgrade --upgrade --all >> "${VRA_INSTALL_LOG}" 2>&1
sleep 10

echo "Restarting all vRA services ..."
/etc/init.d/apache2 restart >> "${VRA_INSTALL_LOG}" 2>&1
/sbin/service rabbitmq-server restart >> "${VRA_INSTALL_LOG}" 2>&1
/etc/init.d/vcac-server restart >> "${VRA_INSTALL_LOG}" 2>&1
/usr/sbin/vcac-vami vco-service-reconfigure >> "${VRA_INSTALL_LOG}" 2>&1
sleep 60

if [ ! -z "${VRA_LICENSE_KEY}" ]; then
  echo "Configuring vRA license key ..."
  /usr/sbin/vcac-vami license-update --key "${VRA_LICENSE_KEY}" >> "${VRA_INSTALL_LOG}" 2>&1
  sleep 10
fi

echo "You can now verify that everything was configured correctly by logging into the Horizon SSO interface at:"
echo -e "\thttps://${VRA_APPLIANCE_HOSTNAME}/vcac"
