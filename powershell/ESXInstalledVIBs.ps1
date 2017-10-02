<#
.SYNOPSIS Retrieve the installation date of an ESXi host
.NOTES  Author:  William Lam
.NOTES  Site:    www.virtuallyghetto.com
.PARAMETER Vmhost
  ESXi host to query installed ESXi VIBs
.EXAMPLE
  Get-ESXInstalledVibs -Vmhost (Get-Vmhost "mini")
.EXAMPLE
  Get-ESXInstalledVibs -Vmhost (Get-Vmhost "mini") -vibname vsan
#>

Function Get-ESXInstalledVibs {
    param(
        [Parameter(
            Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)
        ]
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl]$Vmhost,
        [Parameter(
            Mandatory=$false,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)
        ]
        [String]$vibname=""
     )

     $imageManager = Get-View ($Vmhost.ExtensionData.ConfigManager.ImageConfigManager)
     $vibs = $imageManager.fetchSoftwarePackages()

     foreach ($vib in $vibs) {
        if($vibname -ne "") {
            if($vib.name -eq $vibname) {
                return $vib | select Name, Version, Vendor, CreationDate, Summary
            }
        } else {
            $vib | select Name, Version, Vendor, CreationDate, Summary
        }
     }
}
