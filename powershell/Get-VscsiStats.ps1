<#
.SYNOPSIS Using the vSphere API in vCenter Server to collect ESXTOP & vscsiStats metrics
.NOTES  Author:  William Lam
.NOTES  Site:    www.williamlam.com
.NOTES  Reference: http://www.williamlam.com/2017/02/using-the-vsphere-api-in-vcenter-server-to-collect-esxtop-vscsistats-metrics.html
.PARAMETER Vmhost
  ESXi host
.EXAMPLE
  PS> Get-VMHost -Name "esxi-1" | Get-VscsiStats
#>

Function Get-VscsiStats {
    param(
    [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    [VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl]$VMHost
    )

    $serviceManager = Get-View ($global:DefaultVIServer.ExtensionData.Content.serviceManager) -property "" -ErrorAction SilentlyContinue

    $locationString = "vmware.host." + $VMHost.Name
    $services = $serviceManager.QueryServiceList($null,$locationString)
    foreach ($service in $services) {
        if($service.serviceName -eq "VscsiStats") {
            $serviceView = Get-View $services.Service -Property "entity"
            $serviceView.ExecuteSimpleCommand("FetchAllHistograms")
            break
        }
    }
}

Connect-VIServer -Server 192.168.1.51 -User administrator@vsphere.local -password VMware1! | Out-Null

Get-VMHost -Name "192.168.1.50" | Get-VscsiStats

Disconnect-VIServer * -Confirm:$false
