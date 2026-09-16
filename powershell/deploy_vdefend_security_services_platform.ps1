# Author: William Lam
# Description: Deploy VMware Security Services Platform Installer 5.2 OVA

$SSP_INSTALLER_OVA = "/Volumes/Storage/Software/Security-Services-Platform-Installer-for-vDefend-and-Avi-5.2.0.0.0.25669671.ova"

$VCENTER_HOST = "vc01.vcf.lab"
$VCENTER_USERNAME = "administrator@vsphere.local"
$VCENTER_PASSWORD = "VMware1!VMware1!"
$VCENTER_CLUSTER = "VCF-Mgmt-Cluster"
$VM_NETWORK = "DVPG_FOR_VM_MANAGEMENT"
$VM_DATASTORE = "vsanDatastore"

$SSP_INSTALLER_VMNAME = "ssp-plat01"
$SSP_INSTALLER_FQDN = "ssp-plat01.vcf.lab"
$SSP_INSTALLER_IP = "172.30.0.200"
$SSP_INSTALLER_SUBNET = "255.255.255.0"
$SSP_INSTALLER_GATEWAY = "172.30.0.1"
$SSP_INSTALLER_DNS_SERVERS = "192.168.30.29"
$SSP_INSTALLER_DNS_SEARCH = "vcf.lab"
$SSP_INSTALLER_NTP_SERVERS = "96.19.94.82"
$SSP_INSTALLER_INTERNAL_CLUSTER_CIDR = "10.10.0.0/16"
$SSP_INSTALLER_GRUB_PASSWORD = "VMware1!VMware1!"
$SSP_INSTALLER_SYSADMIN_PASSWORD = "VMware1!VMware1!"
$SSP_INSTALLER_ADMIN_PASSWORD = "VMware1!VMware1!"
$SSP_INSTALLER_AUDIT_PASSWORD = "VMware1!VMware1!"
$SSP_INSTALLER_GRUB_MENU_TIMEOUT = 4
$SSP_INSTALLER_ENABLE_SSH = $true

#### DO NOT EDIT BEYOND HERE

if (-not (Test-Path -LiteralPath $SSP_INSTALLER_OVA -PathType Leaf)) {
    Write-Error "Unable to find SSP Installer OVA: $SSP_INSTALLER_OVA"
    exit 1
}

if (-not $global:DefaultVIServer -or -not $global:DefaultVIServer.IsConnected) {
    Write-Error "No active PowerCLI connection found. Please run Connect-VIServer $VCENTER_HOST -User $VCENTER_USERNAME"
    exit 1
}

$cluster = Get-Cluster -Name $VCENTER_CLUSTER -ErrorAction Stop
$datastore = Get-Datastore -Name $VM_DATASTORE -ErrorAction Stop
$vmHost = $cluster | Get-VMHost | Where-Object { $_.ConnectionState -eq "Connected" } | Select-Object -First 1

if (-not $vmHost) {
    Write-Error "No connected ESXi host was found in cluster $VCENTER_CLUSTER"
    exit 1
}

if (Get-VM -Name $SSP_INSTALLER_VMNAME -ErrorAction SilentlyContinue) {
    Write-Error "A VM named $SSP_INSTALLER_VMNAME already exists"
    exit 1
}

$ovfConfig = Get-OvfConfiguration -Ovf $SSP_INSTALLER_OVA

$ovfConfig.Common.vsx_grub_passwd.Value = $SSP_INSTALLER_GRUB_PASSWORD
$ovfConfig.Common.vsx_grub_menu_timeout.Value = $SSP_INSTALLER_GRUB_MENU_TIMEOUT
$ovfConfig.Common.vsx_passwd_0.Value = $SSP_INSTALLER_SYSADMIN_PASSWORD
$ovfConfig.Common.vsx_cli_passwd_0.Value = $SSP_INSTALLER_ADMIN_PASSWORD
$ovfConfig.Common.vsx_cli_audit_passwd_0.Value = $SSP_INSTALLER_AUDIT_PASSWORD
$ovfConfig.Common.vsx_fqdn.Value = $SSP_INSTALLER_FQDN
$ovfConfig.Common.vsx_ip_0.Value = $SSP_INSTALLER_IP
$ovfConfig.Common.vsx_netmask_0.Value = $SSP_INSTALLER_SUBNET
$ovfConfig.Common.vsx_gateway_0.Value = $SSP_INSTALLER_GATEWAY
$ovfConfig.Common.vsx_internal_cluster_cidr.Value = $SSP_INSTALLER_INTERNAL_CLUSTER_CIDR
$ovfConfig.Common.vsx_dns1_0.Value = $SSP_INSTALLER_DNS_SERVERS
$ovfConfig.Common.vsx_domain_0.Value = $SSP_INSTALLER_DNS_SEARCH
$ovfConfig.Common.vsx_ntp_0.Value = $SSP_INSTALLER_NTP_SERVERS
$ovfConfig.Common.vsx_isSSHEnabled.Value = $SSP_INSTALLER_ENABLE_SSH
$ovfConfig.NetworkMapping.Network_1.Value = $VM_NETWORK

Write-Host -ForegroundColor Green "Deploying Security Services Platform Installer $SSP_INSTALLER_VMNAME ..."
$vm = Import-VApp -Source $SSP_INSTALLER_OVA -OvfConfiguration $ovfConfig -Name $SSP_INSTALLER_VMNAME -Location $cluster -VMHost $vmHost -Datastore $datastore -DiskStorageFormat thin -Force -ErrorAction Stop

Write-Host -ForegroundColor Green "Powering on Security Services Platform Installer $SSP_INSTALLER_VMNAME ..."
$vm | Start-VM -Confirm:$false | Out-Null
