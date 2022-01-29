# Author: William Lam
# Website: www.williamlam.com
# Script to deploy Application Transformer for VMware Tanzu

# ovftool path
OVFTOOL_BIN="/Applications/VMware OVF Tool//ovftool"

# App Transformer OVA
AT_OVA="/Users/lamw/Download/App-Transformer-1.0.0.XXX.ova"

# vCenter
VCENTER_HOSTNAME="vcsa.primp-industries.local"
VCENTER_USERNAME="administrator@vsphere.local"
VCENTER_PASSWORD="VMware1!"
VCENTER_DATACENTER="Primp-Datacenter"
VCENTER_CLUSTER="Supermicro-Cluster"

# Deployment Configuration
AT_DISPLAY_NAME="at.primp-industries.local"
AT_PORTGROUP="Management"
AT_DATASTORE="sm-vsanDatastore"
AT_IPADDRESS="192.168.30.172"
AT_NETMASK="255.255.255.0"
AT_GATEWAY="192.168.30.1"
AT_DNS="192.168.30.2"
AT_DNS_DOMAIN="primp-industries.local"
AT_DNS_SEARCH="primp-industries.local"
AT_NTP="pool.ntp.org"
AT_ROOT_PASSWORD="VMware1!VMware1!"
AT_USERNAME="admin"
AT_PASSWORD="VMware1!VMware1!"
AT_ENCRYPTION_PASSWORD="VMware1!VMware1!"
AT_INSTALL_EMBEDDED_HARBOR="True"

############## DO NOT EDIT BEYOND HERE #################

echo "Deploying Application Transformer for VMware Tanzu OVA: ${AT_DISPLAY_NAME} ..."
"${OVFTOOL_BIN}" --powerOn --acceptAllEulas --noSSLVerify --skipManifestCheck \
"--net:Appliance Network=${AT_PORTGROUP}" \
--datastore=${AT_DATASTORE} \
--diskMode=thin \
--name=${AT_DISPLAY_NAME} \
--prop:vami.ip0.Application_Transformer_for_VMware_Tanzu=${AT_IPADDRESS} \
--prop:vami.netmask0.Application_Transformer_for_VMware_Tanzu=${AT_NETMASK} \
--prop:vami.gateway.Application_Transformer_for_VMware_Tanzu=${AT_GATEWAY} \
--prop:vami.DNS.Application_Transformer_for_VMware_Tanzu=${AT_DNS} \
--prop:vami.domain.Application_Transformer_for_VMware_Tanzu=${AT_DNS_DOMAIN} \
--prop:vami.searchpath.Application_Transformer_for_VMware_Tanzu=${AT_DNS_SEARCH} \
--prop:varoot_password=${AT_ROOT_PASSWORD} \
--prop:iris.username=${AT_USERNAME} \
--prop:iris.password=${AT_PASSWORD} \
--prop:iris.encryption_password=${AT_ENCRYPTION_PASSWORD} \
--prop:install_harbor=${AT_INSTALL_EMBEDDED_HARBOR} \
--prop:appliance.ntp=${AT_NTP} \
${AT_OVA} \
vi://${VCENTER_USERNAME}:${VCENTER_PASSWORD}@${VCENTER_HOSTNAME}/${VCENTER_DATACENTER}/host/${VCENTER_CLUSTER}
