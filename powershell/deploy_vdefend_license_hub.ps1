# Author: William Lam
# Description: Deploy VMware License Hub 2.0 OVA

$LICENSE_HUB_OVA = "/Volumes/Storage/Software/License-Hub-2.0.0.0.0.25630952.ova"

$VCENTER_HOST = "vc01.vcf.lab"
$VCENTER_USERNAME = "administrator@vsphere.local"
$VCENTER_PASSWORD = "VMware1!VMware1!"
$VCENTER_CLUSTER = "VCF-Mgmt-Cluster"
$VM_NETWORK = "DVPG_FOR_VM_MANAGEMENT"
$VM_DATASTORE = "vsanDatastore"

$LICENSE_HUB_VMNAME = "ssp-lic01"
$LICENSE_HUB_FQDN = "ssp-lic01.vcf.lab"
$LICENSE_HUB_IP = "172.30.0.206"
$LICENSE_HUB_SUBNET = "255.255.255.0"
$LICENSE_HUB_GATEWAY = "172.30.0.1"
$LICENSE_HUB_DNS_SERVERS = "192.168.30.29"
$LICENSE_HUB_DNS_SEARCH = "vcf.lab"
$LICENSE_HUB_NTP_SERVERS = "96.19.94.82"
$LICENSE_HUB_INTERNAL_CLUSTER_CIDR = "10.10.0.0/16"
$LICENSE_HUB_KAFKA_FQDN = "ssp-msg02.vcf.lab"
$LICENSE_HUB_IP_POOL = "172.30.0.207-172.30.0.208"
$LICENSE_HUB_GRUB_PASSWORD = "VMware1!VMware1!"
$LICENSE_HUB_SYSADMIN_PASSWORD = "VMware1!VMware1!"
$LICENSE_HUB_ADMIN_PASSWORD = "VMware1!VMware1!"
$LICENSE_HUB_AUDIT_PASSWORD = "VMware1!VMware1!"
$LICENSE_HUB_GRUB_MENU_TIMEOUT = 4
$LICENSE_HUB_ENABLE_SSH = $true

#### DO NOT EDIT BEYOND HERE

if (-not (Test-Path -LiteralPath $LICENSE_HUB_OVA -PathType Leaf)) {
    Write-Error "Unable to find License Hub OVA: $LICENSE_HUB_OVA"
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

if (Get-VM -Name $LICENSE_HUB_VMNAME -ErrorAction SilentlyContinue) {
    Write-Error "A VM named $LICENSE_HUB_VMNAME already exists"
    exit 1
}

$ovfConfig = Get-OvfConfiguration -Ovf $LICENSE_HUB_OVA

$ovfConfig.Common.vsx_grub_passwd.Value = $LICENSE_HUB_GRUB_PASSWORD
$ovfConfig.Common.vsx_grub_menu_timeout.Value = $LICENSE_HUB_GRUB_MENU_TIMEOUT
$ovfConfig.Common.vsx_passwd_0.Value = $LICENSE_HUB_SYSADMIN_PASSWORD
$ovfConfig.Common.vsx_cli_passwd_0.Value = $LICENSE_HUB_ADMIN_PASSWORD
$ovfConfig.Common.vsx_cli_audit_passwd_0.Value = $LICENSE_HUB_AUDIT_PASSWORD
$ovfConfig.Common.vsx_fqdn.Value = $LICENSE_HUB_FQDN
$ovfConfig.Common.vsx_ip_0.Value = $LICENSE_HUB_IP
$ovfConfig.Common.vsx_netmask_0.Value = $LICENSE_HUB_SUBNET
$ovfConfig.Common.vsx_gateway_0.Value = $LICENSE_HUB_GATEWAY
$ovfConfig.Common.vsx_kafka_fqdn.Value = $LICENSE_HUB_KAFKA_FQDN
$ovfConfig.Common.vsx_ip_pool_0.Value = $LICENSE_HUB_IP_POOL
$ovfConfig.Common.vsx_internal_cluster_cidr.Value = $LICENSE_HUB_INTERNAL_CLUSTER_CIDR
$ovfConfig.Common.vsx_dns1_0.Value = $LICENSE_HUB_DNS_SERVERS
$ovfConfig.Common.vsx_domain_0.Value = $LICENSE_HUB_DNS_SEARCH
$ovfConfig.Common.vsx_ntp_0.Value = $LICENSE_HUB_NTP_SERVERS
$ovfConfig.Common.vsx_isSSHEnabled.Value = $LICENSE_HUB_ENABLE_SSH
$ovfConfig.NetworkMapping.Network_1.Value = $VM_NETWORK

Write-Host -ForegroundColor Green "Deploying License Hub $LICENSE_HUB_VMNAME ..."
$vm = Import-VApp -Source $LICENSE_HUB_OVA -OvfConfiguration $ovfConfig -Name $LICENSE_HUB_VMNAME -Location $cluster -VMHost $vmHost -Datastore $datastore -DiskStorageFormat thin -Force -ErrorAction Stop

Write-Host -ForegroundColor Green "Powering on License Hub $LICENSE_HUB_VMNAME ..."
$vm | Start-VM -Confirm:$false | Out-Null
