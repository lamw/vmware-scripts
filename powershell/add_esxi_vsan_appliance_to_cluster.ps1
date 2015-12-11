# William Lam
# www.virtualyghetto.com

$vcname = "192.168.1.150"
$vcuser = "administrator@vghetto.local"
$vcpass = "VMware1!"
$esxhosts = @("192.168.1.190", "192.168.1.191", "192.168.1.192")
$esxuser = "root"
$esxpass = "VMware1!"
$cluster = "VSAN-Cluster"

#### DO NOT EDIT BEYOND HERE ####

$vcenter = Connect-VIServer $vcname -User $vcuser -Password $vcpass -WarningAction SilentlyContinue

$cluster_ref = Get-Cluster $cluster

$tasks = @()
foreach($esxhost in $esxhosts) {
    Write-Host "Adding $esxhost to $cluster ..."
    Add-VMHost -Name $esxhost -Location $cluster_ref -User $esxuser -Password $esxpass -Force | out-null
}

$spec = New-Object VMware.Vim.ClusterConfigSpecEx
$vsanconfig = New-Object VMware.Vim.VsanClusterConfigInfo
$defaultconfig = New-Object VMware.Vim.VsanClusterConfigInfoHostDefaultInfo
$defaultconfig.AutoClaimStorage = $true
$vsanconfig.DefaultConfig = $defaultconfig
$vsanconfig.enabled = $true
$spec.VsanConfig = $vsanconfig

Write-Host "Enabling VSAN Cluster on $cluster ..."
$task = $cluster_ref.ExtensionData.ReconfigureComputeResource_Task($spec,$true)
$task1 = Get-Task -Id ("Task-$($task.value)")
$task1 | Wait-Task | out-null

Disconnect-VIServer $vcenter -Confirm:$false
