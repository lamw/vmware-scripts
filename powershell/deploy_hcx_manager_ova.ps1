# Load OVF/OVA configuration into a variable
$ovffile = "C:\Users\william\Desktop\VMware-HCX-Enterprise-3.5.1-10027070.ova"
$ovfconfig = Get-OvfConfiguration $ovffile

# vSphere Cluster + VM Network configurations
$Cluster = "Cluster-01"
$VMName = "MGMT-HCXM-02"
$VMNetwork = "SJC-CORP-MGMT-EP"
$HCXAddressToVerify = "mgmt-hcxm-02.cpbu.corp"

$VMHost = Get-Cluster $Cluster | Get-VMHost | Sort MemoryGB | Select -first 1
$Datastore = $VMHost | Get-datastore | Sort FreeSpaceGB -Descending | Select -first 1
$Network = Get-VDPortGroup -Name $VMNetwork

# Fill out the OVF/OVA configuration parameters

# vSphere Portgroup Network Mapping
$ovfconfig.NetworkMapping.VSMgmt.value = $Network

# IP Address
$ovfConfig.common.mgr_ip_0.value = "172.17.31.50"

# Netmask
$ovfConfig.common.mgr_prefix_ip_0.value = "24"

# Gateway
$ovfConfig.common.mgr_gateway_0.value = "172.17.31.253"

# DNS Server
$ovfConfig.common.mgr_dns_list.value = "172.17.31.5"

# DNS Domain
$ovfConfig.common.mgr_domain_search_list.value  = "cpbu.corp"

# Hostname
$ovfconfig.Common.hostname.Value = "mgmt-hcxm-02.cpbu.corp"

# NTP
$ovfconfig.Common.mgr_ntp_list.Value = "172.17.31.5"

# SSH
$ovfconfig.Common.mgr_isSSHEnabled.Value = $true

# Password
$ovfconfig.Common.mgr_cli_passwd.Value = "VMware1!"
$ovfconfig.Common.mgr_root_passwd.Value = "VMware1!"

# Deploy the OVF/OVA with the config parameters
Write-Host -ForegroundColor Green "Deploying HCX Manager OVA ..."
$vm = Import-VApp -Source $ovffile -OvfConfiguration $ovfconfig -Name $VMName -VMHost $vmhost -Datastore $datastore -DiskStorageFormat thin

# Power On the HCX Manager VM after deployment
Write-Host -ForegroundColor Green "Powering on HCX Manager ..."
$vm | Start-VM -Confirm:$false | Out-Null

# Waiting for HCX Manager to initialize
while(1) {
    try {
        if($PSVersionTable.PSEdition -eq "Core") {
            $requests = Invoke-WebRequest -Uri "https://$($HCXAddressToVerify):9443" -Method GET -SkipCertificateCheck -TimeoutSec 5
        } else {
            $requests = Invoke-WebRequest -Uri "https://$($HCXAddressToVerify):9443" -Method GET -TimeoutSec 5
        }
        if($requests.StatusCode -eq 200) {
            Write-Host -ForegroundColor Green "HCX Manager is now ready to be configured!"
            break
        }
    }
    catch {
        Write-Host -ForegroundColor Yellow "HCX Manager is not ready yet, sleeping for 120 seconds ..."
        sleep 120
    }
}