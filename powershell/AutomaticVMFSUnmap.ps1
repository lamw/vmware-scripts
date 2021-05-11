<#
.SYNOPSIS Retrieve the current VMFS Unmap priority for VMFS 6 datastore
.NOTES  Author:  William Lam
.NOTES  Site:    www.williamlam.com
.NOTES  Reference: http://www.williamlam.com/2016/10/configure-new-automatic-space-reclamation-vmfs-unmap-using-vsphere-6-5-apis.html
.PARAMETER Datastore
  VMFS 6 Datastore to enable or disable VMFS Unamp
.EXAMPLE
  Get-Datastore "mini-local-datastore-hdd" | Get-VMFSUnmap
#>

Function Get-VMFSUnmap {
    param(
        [Parameter(
            Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)
        ]
        [VMware.VimAutomation.ViCore.Impl.V1.DatastoreManagement.DatastoreImpl]$Datastore
     )

     $datastoreInfo = $Datastore.ExtensionData.Info

     if($datastoreInfo -is [VMware.Vim.VmfsDatastoreInfo] -and $datastoreInfo.Vmfs.MajorVersion -eq 6) {
        $datastoreInfo.Vmfs | select Name, UnmapPriority, UnmapGranularity
     } else {
        Write-Host "Not a VMFS Datastore and/or VMFS version is not 6.0"
     }
}

<#
.SYNOPSIS Configure the VMFS Unmap priority for VMFS 6 datastore
.NOTES  Author:  William Lam
.NOTES  Site:    www.williamlam.com
.NOTES  Reference: http://www.williamlam.com/2016/10/configure-new-automatic-space-reclamation-vmfs-unmap-using-vsphere-6-5-apis.html
.PARAMETER Datastore
  VMFS 6 Datastore to enable or disable VMFS Unamp
.EXAMPLE
  Get-Datastore "mini-local-datastore-hdd" | Set-VMFSUnmap -Enabled $true
.EXAMPLE
  Get-Datastore "mini-local-datastore-hdd" | Set-VMFSUnmap -Enabled $false
#>

Function Set-VMFSUnmap {
    param(
        [Parameter(
            Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)
        ]
        [VMware.VimAutomation.ViCore.Impl.V1.DatastoreManagement.DatastoreImpl]$Datastore,
        [String]$Enabled
     )

    $vmhostView = ($Datastore | Get-VMHost).ExtensionData
    $storageSystem = Get-View $vmhostView.ConfigManager.StorageSystem

    if($Enabled -eq $true) {
        $enableUNMAP = "low"
        $reconfigMessage = "Enabling Automatic VMFS Unmap for $Datastore"
    } else {
        $enableUNMAP = "none"
        $reconfigMessage = "Disabling Automatic VMFS Unmap for $Datastore"
    }

    $uuid = $datastore.ExtensionData.Info.Vmfs.Uuid

    Write-Host "$reconfigMessage ..."
    $storageSystem.UpdateVmfsUnmapPriority($uuid,$enableUNMAP)
}
