#!/bin/bash
# William Lam
# www.virtuallyghetto.com

# Primary vCenter Server Configurations 
PRIMARY_VC=vcenter55-3.primp-industries.com
VC_USERNAME=administrator@vsphere.local
VC_PASSWORD=VMware1!
SSO_SITE_NAME=palo-alto

# Active Directory Configurations
JOIN_AD=0
AD_DOMAIN=primp-industries.com
AD_USER=ad-username
AD_PASS=ad-password
 
## DO NOT EDIT BEYOND HERE ##
 
echo "Accepting EULA ..."
/usr/sbin/vpxd_servicecfg eula accept
 
if [ ${JOIN_AD} -eq 1 ]; then
	echo "Configuring Active Directory ..."
	/usr/sbin/vpxd_servicecfg ad write "${AD_USER}" "${AD_PASS}" "${AD_DOMAIN}"
fi
 
echo "Extracting Primary VC Lookup Service SSL Thumbprint ..."
echo "" | openssl s_client -connect "${PRIMARY_VC}:7444" 2> /dev/null 1> /tmp/cert
SSL_THUMBPRINT=$(openssl x509 -in /tmp/cert -fingerprint -sha1 -noout | awk -F '=' '{print $2}')
echo ${SSL_THUMBPRINT}
 
echo "Accepting EULA ..."
/usr/sbin/vpxd_servicecfg eula accept
 
echo "Configuring Embedded DB ..."
/usr/sbin/vpxd_servicecfg db write embedded
 
echo "Creating Lookup Service URL file ..."
echo "${PRIMARY_VC}:7444/lookupservice/sdk" > /etc/vmware-sso/ls_url.txt
 
echo "Configuring SSO..."
/usr/sbin/vpxd_servicecfg sso write external https://${PRIMARY_VC}:7444/lookupservice/sdk "${VC_USERNAME}" "${VC_PASSWORD}" "${VC_USERNAME}" false "${SSL_THUMBPRINT}"
 
echo "Starting VCSA ..."
/usr/sbin/vpxd_servicecfg service start

echo "Starting VMware SSO Services ..."
/etc/init.d/vmdird start
/sbin/chkconfig vmdird on
/etc/init.d/vmware-sts-idmd start
/sbin/chkconfig vmware-sts-idmd on
/etc/init.d/vmkdcd start
/sbin/chkconfig vmkdcd on
/etc/init.d/vmcad start
/sbin/chkconfig vmcad on

echo "Joining ${PRIMARY_VC} ..."
/usr/lib/vmware-vmdir/bin/vdcpromo -u "${VC_USERNAME}" -w "${VC_PASSWORD}" -s "${SSO_SITE_NAME}" -H ${PRIMARY_VC}
