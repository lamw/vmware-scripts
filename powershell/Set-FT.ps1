# Author: William Lam
# Blog: www.virtuallyghetto.com
# Description: Configure SMP-FT for a Virtual Machine in vSphere 6.0
# Reference: http://www.virtuallyghetto.com/2016/02/new-vsphere-6-0-api-for-configuring-smp-ft.html

<#
.SYNOPSIS  Configure SMP-FT for a Virtual Machine
.DESCRIPTION The function will allow you to enable/disable SMP-FT for a Virtual Machine
.NOTES  Author:  William Lam
.NOTES  Site:    www.virtuallyghetto.com
.PARAMETER Vmname
  Virtual Machine object to perform SMP-FT operation
.PARAMETER Operation
  on/off
.PARAMETER Datastore
  The Datastore to store secondary VM as well as the VM's configuration file (Default assumes same datastore but this can be changed)
.PARAMETER Vmhost
  The ESXi host in which to store the secondary VM
.EXAMPLE
  PS> Set-FT -vmname "SMP-VM" -Operation [on|off] -Datastore "vsanDatastore" -Vmhost "vesxi60-5.primp-industries.com"
#>

Function Set-FT {
    param(
    [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    $vmname,
    $operation,
    $datastore,
    $vmhost
    )

    process {
        # Retrieve VM View
        $vmView = Get-View -ViewType VirtualMachine -Property Name,Config.Hardware.Device -Filter @{"name"=$vmname}

        # Retrieve Datastore View
        $datastoreView = Get-View -ViewType Datastore -Property Name -Filter @{"name"=$datastore}

        # Retrieve ESXi View
        $vmhostView = Get-View -ViewType HostSystem -Property Name -Filter @{"name"=$vmhost}

        # VM Devices
        $devices = $vmView.Config.Hardware.Device

        $diskArray = @()
        # Build VM Disk Array to map to datastore
        foreach ($device in $d) {
	        if($device -is [VMware.Vim.VirtualDisk]) {
		        $temp = New-Object Vmware.Vim.FaultToleranceDiskSpec
                $temp.Datastore = $datastoreView.Moref
                $temp.Disk = $device
                $diskArray += $temp
	        }
        }

        # FT Config Spec
        $spec = New-Object VMware.Vim.FaultToleranceConfigSpec
        $metadataSpec = New-Object VMware.Vim.FaultToleranceMetaSpec
        $metadataSpec.metaDataDatastore = $datastoreView.MoRef
        $secondaryVMSepc = New-Object VMware.Vim.FaultToleranceVMConfigSpec
        $secondaryVMSepc.vmConfig = $datastoreView.MoRef
        $secondaryVMSepc.disks = $diskArray
        $spec.metaDataPath = $metadataSpec
        $spec.secondaryVmSpec = $secondaryVMSepc

        if($operation -eq "on") {
            $task = $vmView.CreateSecondaryVMEx_Task($vmhostView.MoRef,$spec)
        } elseif($operation -eq "off") {
            $task = $vmView.TurnOffFaultToleranceForVM_Task()
        } else {
            Write-Host "Invalid Selection"
            exit 1
        }
        $task1 = Get-Task -Id ("Task-$($task.value)")
        $task1 | Wait-Task
    }
}
