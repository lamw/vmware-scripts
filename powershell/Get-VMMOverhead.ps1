# Author: William Lam
# Blog: www.williamlam.com
# Description: Retrieves the VM memory overhead for given VM
# Reference: http://www.williamlam.com/2015/12/easily-retrieve-vm-memory-overhead-using-the-vsphere-6-0-api.html

<#
.SYNOPSIS  Returns VM Ovehead a VM
.DESCRIPTION The function will return VM memory overhead
    for a given Virtual Machine
.NOTES  Author:  William Lam
.NOTES  Site:    www.williamlam.com
.PARAMETER Vm
  Virtual Machine object to query VM memory overhead
.EXAMPLE
  PS> Get-VM "vcenter60-2" | Get-VMMemOverhead
#>

Function Get-VMMemOverhead {
    param(  
    [Parameter(
        Position=0, 
        Mandatory=$true, 
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    [Alias('FullName')]
    [VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl[]]$VM
    ) 

    process {
        # Retrieve VM & ESXi MoRef
        $vmMoref = $VM.ExtensionData.MoRef
        $vmHostMoref = $VM.ExtensionData.Runtime.Host

        # Retrieve Overhead Memory Manager
        $overheadMgr = Get-View ($global:DefaultVIServer.ExtensionData.Content.OverheadMemoryManager)

        # Get VM Memory overhead
        $overhead = $overheadMgr.LookupVmOverheadMemory($vmMoref,$vmHostMoref)
        Write-Host $VM.Name "has overhead of" ([math]::Round($overhead/1MB,2)).ToString() "MB memory`n"
    }
}
