# Author: William Lam
# Website: www.virtuallyghetto.com

$NSXTEdgeOVA = "C:\Users\william\Desktop\Project-Pacific\nsx-edge-3.0.0.0.0.15946012.ova"

# vCenter Server used to deploy NSX-T Edge
$VMCluster = "Cluster-01"
$VMNetwork = "SJC-CORP-NESTED-1736"
$VMDatastore = "vsanDatastore"
$VMNetmask = "255.255.255.0"
$VMGateway = "172.17.36.253"
$VMDNS = "172.17.31.5"
$VMNTP = "pool.ntp.org"
$VMDomain = "cpbu.corp"

# NSX-T Manager to add Edge to
$NSXTMgrIPAddress = "172.17.36.14"
$NSXTMgrUsername = "admin"
$NSXTMgrPassword = "VMware1!VMware1!"

# NSX-T Edge Configuration
$NSXTEdgeDeploymentSize = "medium"
$NSXTEdgevCPU = "8" #override default size
$NSXTEdgevMEM = "32" #override default size
$NSXTEdgeHostnameToIPs = @{
    "pacific-nsx-edge-2a" = "172.17.36.15"
}

$NSXRootPassword = "VMware1!VMware1!"
$NSXAdminUsername = "admin"
$NSXAdminPassword = "VMware1!VMware1!"
$NSXAuditUsername = "audit"
$NSXAuditPassword = "VMware1!VMware1!"
$NSXSSHEnable = "false"
$NSXEnableRootLogin = "true"
$NSXVTEPNetwork = "Pacific-VTEP"

$cluster = Get-Cluster $VMCluster
$datastore = Get-Datastore $VMDatastore
$vmhost = $cluster | Get-VMHost | Get-Random

Write-Host "Connecting to NSX-T Manager ..."
if(!(Connect-NsxtServer -Server $NSXTMgrIPAddress -Username $NSXTMgrUsername -Password $NSXTMgrPassword -WarningAction SilentlyContinue)) {
    Write-Host -ForegroundColor Red "Unable to connect to NSX-T Manager, please check the deployment"
    exit
} else {
    Write-Host "Successfully logged into NSX-T Manager $NSXTMgrHostname ..."
}

# Retrieve NSX Manager Thumbprint which will be needed later
Write-Host "Retrieving NSX Manager Thumbprint ..."
$nsxMgrID = ((Get-NsxtService -Name "com.vmware.nsx.cluster.nodes").list().results | where {$_.manager_role -ne $null}).id
$nsxMgrCertThumbprint = (Get-NsxtService -Name "com.vmware.nsx.cluster.nodes").get($nsxMgrID).manager_role.api_listen_addr.certificate_sha256_thumbprint

Write-Host "Disconnecting from NSX-T Manager ..."
Disconnect-NsxtServer -Confirm:$false

# Deploy Edges
$nsxEdgeOvfConfig = Get-OvfConfiguration $NSXTEdgeOVA
$NSXTEdgeHostnameToIPs.GetEnumerator() | Sort-Object -Property Value | Foreach-Object {
    $VMName = $_.Key
    $VMIPAddress = $_.Value
    $VMHostname = "$VMName" + "@" + $VMDomain

    $nsxEdgeOvfConfig.DeploymentOption.Value = $NSXTEdgeDeploymentSize
    $nsxEdgeOvfConfig.NetworkMapping.Network_0.value = $VMNetwork
    $nsxEdgeOvfConfig.NetworkMapping.Network_1.value = $NSXVTEPNetwork
    $nsxEdgeOvfConfig.NetworkMapping.Network_2.value = $VMNetwork
    $nsxEdgeOvfConfig.NetworkMapping.Network_3.value = $VMNetwork

    $nsxEdgeOvfConfig.Common.nsx_hostname.Value = $VMHostname
    $nsxEdgeOvfConfig.Common.nsx_ip_0.Value = $VMIPAddress
    $nsxEdgeOvfConfig.Common.nsx_netmask_0.Value = $VMNetmask
    $nsxEdgeOvfConfig.Common.nsx_gateway_0.Value = $VMGateway
    $nsxEdgeOvfConfig.Common.nsx_dns1_0.Value = $VMDNS
    $nsxEdgeOvfConfig.Common.nsx_domain_0.Value = $VMDomain
    $nsxEdgeOvfConfig.Common.nsx_ntp_0.Value = $VMNTP

    $nsxEdgeOvfConfig.Common.mpUser.Value = $NSXTMgrUsername
    $nsxEdgeOvfConfig.Common.mpPassword.Value = $NSXTMgrPassword
    $nsxEdgeOvfConfig.Common.mpIp.Value = $NSXTMgrIPAddress
    $nsxEdgeOvfConfig.Common.mpThumbprint.Value = $nsxMgrCertThumbprint

    if($NSXSSHEnable -eq "true") {
        $NSXSSHEnableVar = $true
    } else {
        $NSXSSHEnableVar = $false
    }
    $nsxEdgeOvfConfig.Common.nsx_isSSHEnabled.Value = $NSXSSHEnableVar
    if($NSXEnableRootLogin -eq "true") {
        $NSXRootPasswordVar = $true
    } else {
        $NSXRootPasswordVar = $false
    }
    $nsxEdgeOvfConfig.Common.nsx_allowSSHRootLogin.Value = $NSXRootPasswordVar

    $nsxEdgeOvfConfig.Common.nsx_passwd_0.Value = $NSXRootPassword
    $nsxEdgeOvfConfig.Common.nsx_cli_username.Value = $NSXAdminUsername
    $nsxEdgeOvfConfig.Common.nsx_cli_passwd_0.Value = $NSXAdminPassword
    $nsxEdgeOvfConfig.Common.nsx_cli_audit_username.Value = $NSXAuditUsername
    $nsxEdgeOvfConfig.Common.nsx_cli_audit_passwd_0.Value = $NSXAuditPassword

    Write-Host "Deploying NSX Edge VM $VMName ..."
    $nsxedge_vm = Import-VApp -Source $NSXTEdgeOVA -OvfConfiguration $nsxEdgeOvfConfig -Name $VMName -Location $cluster -VMHost $vmhost -Datastore $datastore -DiskStorageFormat thin

    Write-Host "Updating vCPU Count to $NSXTEdgevCPU & vMEM to $NSXTEdgevMEM GB ..."
    Set-VM -Server $viConnection -VM $nsxedge_vm -NumCpu $NSXTEdgevCPU -MemoryGB $NSXTEdgevMEM -Confirm:$false

    Write-Host "Powering On $VMName ..."
    $nsxedge_vm | Start-Vm -RunAsync | Out-Null
}

