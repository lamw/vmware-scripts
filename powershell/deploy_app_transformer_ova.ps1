# Author: William Lam
# Website: www.williamlam.com
# Script to deploy Application Transformer for VMware Tanzu

# Load OVF/OVA configuration into a variable
$ovffile = "/Users/lamw/Download/App-Transformer-1.0.0.XXX.ova"
$ovfconfig = Get-OvfConfiguration $ovffile

# Deployment Configuration
$VMCluster = "Supermicro-Cluster"
$AT_DISPLAY_NAME = "at.primp-industries.local"
$AT_PORTGROUP = "Management"
$AT_IP = "192.168.30.172"
$AT_NETMASK = "255.255.255.0"
$AT_GATEWAY = "192.168.30.1"
$AT_DNS = "192.168.30.2"
$AT_DNS_DOMAIN = "primp-industries.local"
$AT_DNS_SEARCH = "primp-industries.local"
$AT_NTP = "pool.ntp.org"
$AT_ROOT_PASSWORD = "VMware1!VMware1!"
$AT_USERNAME = "admin"
$AT_PASSWORD = "VMware1!VMware1!"
$AT_ENCRYPTION_PASSWORD = "VMware1!VMware1!"
$AT_INSTALL_EMBEDDED_HARBOR = $true

############## DO NOT EDIT BEYOND HERE #################

$VMHost = Get-Cluster $VMCluster | Get-VMHost | Sort-Object MemoryGB | Select -first 1
$Datastore = $VMHost | Get-datastore | Sort-Object FreeSpaceGB -Descending | Select -first 1
$Network = Get-VDPortGroup -Name $AT_PORTGROUP

# Fill out the OVF/OVA configuration parameters

# vSphere Portgroup Network Mapping
$ovfconfig.NetworkMapping.Appliance_Network.value = $Network

# IP Address
$ovfConfig.vami.Application_Transformer_for_VMware_Tanzu.ip0.value = $AT_IP

# Netmask
$ovfConfig.vami.Application_Transformer_for_VMware_Tanzu.netmask0.value = $AT_NETMASK

# Gateway
$ovfConfig.vami.Application_Transformer_for_VMware_Tanzu.gateway.value = $AT_GATEWAY

# DNS Server
$ovfConfig.vami.Application_Transformer_for_VMware_Tanzu.DNS.value = $AT_DNS

# DNS Domain
$ovfConfig.vami.Application_Transformer_for_VMware_Tanzu.domain.value  = $AT_DNS_DOMAIN

# DNS Search Path
$ovfConfig.vami.Application_Transformer_for_VMware_Tanzu.searchpath.value  = $AT_DNS_SEARCH

# Root Password
$ovfconfig.Common.varoot_password.Value = $AT_ROOT_PASSWORD

# App Transformer Username
$ovfconfig.Common.iris.username.value = $AT_USERNAME

# App Transformer Password
$ovfconfig.Common.iris.password.value = $AT_PASSWORD

# App Transformer Encryption Password
$ovfconfig.Common.iris.encryption_password.value = $AT_ENCRYPTION_PASSWORD

# Install Embedded Harbor
$ovfconfig.Common.install_harbor.value = $AT_INSTALL_EMBEDDED_HARBOR

# NTP
$ovfconfig.Common.appliance.ntp.Value = $AT_NTP

# Deploy the OVF/OVA with the config parameters
Write-Host -ForegroundColor Green "Deploying Application Transformer for VMware Tanzu OVA ..."
$vm = Import-VApp -Source $ovffile -OvfConfiguration $ovfconfig -Name $AT_DISPLAY_NAME -VMHost $vmhost -Datastore $datastore -DiskStorageFormat thin

# Power On the App Transformer VM after deployment
Write-Host -ForegroundColor Green "Powering on App Transformer ..."
$vm | Start-VM -Confirm:$false | Out-Null

# Waiting for App Transformer to initialize
while(1) {
    try {
        $requests = Invoke-WebRequest -Uri "https://${AT_IP}:443" -Method GET -SkipCertificateCheck -TimeoutSec 5

        if($requests.StatusCode -eq 200) {
            Write-Host -ForegroundColor Green "App Transformer is now ready!"
            break
        }
    }
    catch {
        Write-Host -ForegroundColor Yellow "App Transformer is not ready yet, sleeping for 120 seconds ..."
        sleep 120
    }
}