<#
.SYNOPSIS Retrieve the installation date of an ESXi host
.NOTES  Author:  William Lam
.NOTES  Site:    www.virtuallyghetto.com
.NOTES  Reference: http://www.virtuallyghetto.com/2016/10/super-easy-way-of-getting-esxi-installation-date-in-vsphere-6-5.html
.PARAMETER Vmhost
  ESXi host to query installation date
.EXAMPLE
  Get-Vmhost "mini" | Get-ESXInstallDate
#>

Function Get-ESXInstallDate {
    param(
        [Parameter(
            Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)
        ]
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl]$Vmhost
     )

     if($Vmhost.Version -eq "6.5.0") {
        $imageManager = Get-View ($Vmhost.ExtensionData.ConfigManager.ImageConfigManager)
        $installDate = $imageManager.installDate()

        Write-Host "$Vmhost was installed on $installDate"
     } else {
        Write-Host "ESXi must be running 6.5"
     }
}
