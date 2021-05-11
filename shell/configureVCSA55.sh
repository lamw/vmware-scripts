# Author: William Lam
# Site: www.williamlam.com
# Reference: http://www.williamlam.com/2015/01/completely-automating-vcenter-server-appliance-vcsa-5-5-configurations.html

# User Configurations

# SSO Administrator password (administrator@vsphere.local)
SSO_ADMINISTRATOR_PASSWORD=vmware

# Join Active Directory (following 5 variables required)
JOIN_AD=0
AD_DOMAIN=primp-industries.com
AD_USER=administrator
AD_PASS=MYSUPERDUPERSTRONGPASSWORD
VCENTER_HOSTNAME=vcenter55-2.primp-industries.com

# Enable NTP
ENABLE_NTP=0
NTP_SERVERS=0.pool.ntp.org

# VCSA expected Inentory Size (small, medium or large) - Details https://pubs.vmware.com/vsphere-55/index.jsp?topic=%2Fcom.vmware.vsphere.install.doc%2FGUID-67C4D2A0-10F7-4158-A249-D1B7D7B3BC99.html
VCSA_INVENTORY_SIZE=small

# Enable VMware Customer Experience Improvement Program
ENABLE_VC_TELEMTRY=0

################ DO NOT EDIT BEYOND HERE ################

# Method to check the return code from vpxd_servicefg which should return 0 for success
# This allows the script to validate the operations was successful without being so verbose 
# the output
checkStatusCode() {
        FILE=$1

        grep 'VC_CFG_RESULT=0' ${FILE} > /dev/null 2>&1
        if [ $? -eq 1 ]; then
                echo "Something went wrong, output from command:"
                cat ${FILE}
                exit 1;
        fi
}

setEula() {
        echo -e "\nAccepting VMware EULA ..."
        /usr/sbin/vpxd_servicecfg eula accept > /tmp/vcsa-deploy
        checkStatusCode /tmp/vcsa-deploy
}

setInventorySize() {
        echo "Configuring vCenter Server Inventory Size to ${VCSA_INVENTORY_SIZE} ..."

        if [ ${VCSA_INVENTORY_SIZE} == "medium" ]; then
                /usr/sbin/vpxd_servicecfg 'jvm-max-heap' 'write' '512' '6144' '2048' > /tmp/vcsa-deploy
                checkStatusCode /tmp/vcsa-deploy
        elif [ ${VCSA_INVENTORY_SIZE} == "large" ]; then
                /usr/sbin/vpxd_servicecfg 'jvm-max-heap' 'write' '1024' '12288' '4096' > /tmp/vcsa-deploy
                checkStatusCode /tmp/vcsa-deploy
        else #default to small
                /usr/sbin/vpxd_servicecfg 'jvm-max-heap' 'write' '512' '3072' '1024' > /tmp/vcsa-deploy
                checkStatusCode /tmp/vcsa-deploy
        fi
}

setActiveDirectory() {
        if [ ${JOIN_AD} -eq 1 ]; then
                echo "Configuring vCenter Server hostname ..."
                SHORTHOSTNAME=$(echo ${VCENTER_HOSTNAME} |  cut -d. -f1)
                /bin/hostname ${VCENTER_HOSTNAME}

                echo ${VCENTER_HOSTNAME} > /etc/HOSTNAME
                sed -i "s/localhost/${SHORTHOSTNAME}/g" /etc/hosts

                echo "Configuring Active Directory ..."
                /usr/sbin/vpxd_servicecfg ad write "${AD_USER}" "${AD_PASS}" ${AD_DOMAIN} > /tmp/vcsa-deploy
                checkStatusCode /tmp/vcsa-deploy

                echo "Adding DNS Search Domain ..."
                echo "search ${AD_DOMAIN}" >> /etc/resolv.conf

                echo "Enabling SSL Certificate re-generation, please ensure you REBOOT once the script completes ..."
                touch /etc/vmware-vpx/ssl/allow_regeneration
        fi
}

setNTP() {
echo "Enbaling Time Synchronization ..."
        if [ ${ENABLE_NTP} -eq 1 ]; then
                /usr/sbin/vpxd_servicecfg timesync write ntp ${NTP_SERVERS} > /tmp/vcsa-deploy
                checkStatusCode /tmp/vcsa-deploy
        else
                /usr/sbin/vpxd_servicecfg timesync write tools > /tmp/vcsa-deploy
                checkStatusCode /tmp/vcsa-deploy
        fi
}

setVCDB() {
        echo "Configuring vCenter Server Embedded DB ..."
        /usr/sbin/vpxd_servicecfg db write embedded &> /tmp/vcsa-deploy
        checkStatusCode /tmp/vcsa-deploy
}

setSSODB() {
        echo "Configuring vCenter Server SSO w/custom administrator@vsphere.local password ..."
        /usr/sbin/vpxd_servicecfg sso write embedded ${SSO_ADMINISTRATOR_PASSWORD} > /tmp/vcsa-deploy
        checkStatusCode /tmp/vcsa-deploy
}

setSSOIdentitySource() {
        if [ ${JOIN_AD} -eq 1 ]; then
                echo "Adding Active Directory Identity Source to SSO ..."
                # Reference http://kb.vmware.com/kb/2063424
                EXPORTED_SSO_PROPERTIES=/usr/lib/vmware-upgrade/sso/exported_sso.properties
                if [ -e ${EXPORTED_SSO_PROPERTIES} ] ;then
                        rm -f  ${EXPORTED_SSO_PROPERTIES}
                fi

                cat > ${EXPORTED_SSO_PROPERTIES} << __SSO_EXPORT_CONF__
ExternalIdentitySource.${AD_DOMAIN}.name=${AD_DOMAIN}
ExternalIdentitySource.${AD_DOMAIN}.type=0
ExternalIdentitySourcesDomainNames=${AD_DOMAIN}
__SSO_EXPORT_CONF__

                /usr/lib/vmware-upgrade/sso/sso_import.sh > /dev/null 2>&1
                rm -rf ${EXPORTED_SSO_PROPERTIES}

                echo "Configuring ${AD_DOMAIN} as default Identity Source ..."
                # Reference http://kb.vmware.com/kb/2070433
                SSO_LDIF_CONF=/tmp/defaultdomain.ldif
                cat > ${SSO_LDIF_CONF} << __DEFAULT_SSO_DOMAIN__
dn: cn=vsphere.local,cn=Tenants,cn=IdentityManager,cn=Services,dc=vsphere,dc=local
changetype: modify
replace: vmwSTSDefaultIdentityProvider
vmwSTSDefaultIdentityProvider: ${AD_DOMAIN}
__DEFAULT_SSO_DOMAIN__
                ldapmodify -f ${SSO_LDIF_CONF} -h localhost -p 11711 -D "cn=Administrator,cn=Users,dc=vsphere,dc=local" -w ${SSO_ADMINISTRATOR_PASSWORD} > /dev/null 2>&1
                if [ $? -eq 1 ]; then
                        echo "Unable to update Default SSO Domain for some reason"
                        exit 1
                fi
                rm -f ${SSO_LDIF_CONF}
        fi
}

startVC() {
        echo "Starting the vCenter Server Service ..."
        /usr/sbin/vpxd_servicecfg service start > /tmp/vcsa-deploy
        checkStatusCode /tmp/vcsa-deploy
}

setVCTelemtry() {
        if [[ -e /var/log/vmware/phonehome ]] && [[ ${ENABLE_VC_TELEMTRY} -eq 1 ]]; then
                echo "Enabling vCenter Server Telemtry ..."
                /usr/sbin/vpxd_servicecfg telemetry enable > /tmp/vcsa-deploy
                checkStatusCode /tmp/vcsa-deploy
        fi
}

### START OF SCRIPT ### 

setEula
setInventorySize
setActiveDirectory  
setNTP
setVCDB
setSSODB
setSSOIdentitySource  
startVC
setVCTelemtry
