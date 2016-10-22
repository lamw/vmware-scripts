<#
.SYNOPSIS
   This script demonstrates an xVC-vMotion where a running Virtual Machine
   is live migrated between two vCenter Servers which are NOT part of the
   same SSO Domain which is only available using the vSphere 6.0 API.

   This script also supports live migrating a running Virtual Machine between
   two vCenter Servers that ARE part of the same SSO Domain (aka Enhanced Linked Mode)

   This script also supports migrating VMs connected to both a VSS/VDS as well as having multiple vNICs
.NOTES
   File Name  : xMove-VM.ps1
   Author     : William Lam - @lamw
   Modified   : Alex Thomson (disk spec components from Grzegorz Kulikowski)
   Version    : 1.1
.LINK
    http://www.virtuallyghetto.com/2016/05/automating-cross-vcenter-vmotion-xvc-vmotion-between-the-same-different-sso-domain.html
.LINK
   https://github.com/lamw

.INPUTS
   sourceVCConnection, destVCConnection, vm, switchtype, switch,
   cluster, datastore, vmhost, vmnetworks,
.OUTPUTS
   Console output
#>

Function xMove-VM {
    param(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
    [VMware.VimAutomation.ViCore.Util10.VersionedObjectImpl]$sourcevc,
    [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
    [VMware.VimAutomation.ViCore.Util10.VersionedObjectImpl]$destvc,
    [Parameter(Mandatory=$true)]
    [String]$vm,
    [Parameter(Mandatory=$true)]
    [String]$switchtype,
    [Parameter(Mandatory=$false)]
    [String]$switch,
    [Parameter(Mandatory=$true)]
    [String]$cluster,
    [parameter(Mandatory=$false)]
    [String]$datastore,
    [Paraneter(Mandatory=$true)]
    [String]$sourceVMHost,
    [Parameter(Mandatory=$true)]
    [String]$vmhost,
    [Parameter(Mandatory=$false)]
    [String]$vmnetworks
    )

    #Create Relocation Spec for use in the function
    $spec = New-Object VMware.Vim.VirtualMachineRelocateSpec

    # Retrieve Source VC SSL Thumbprint
    $vcurl = "https://" + $destVC
    add-type @"
        using System.Net;
        using System.Security.Cryptography.X509Certificates;

            public class IDontCarePolicy : ICertificatePolicy {
            public IDontCarePolicy() {}
            public bool CheckValidationResult(
                ServicePoint sPoint, X509Certificate cert,
                WebRequest wRequest, int certProb) {
                return true;
            }
        }
"@
    [System.Net.ServicePointManager]::CertificatePolicy = new-object IDontCarePolicy
    # Need to do simple GET connection for this method to work
    Invoke-RestMethod -Uri $VCURL -Method Get | Out-Null

    $endpoint_request = [System.Net.Webrequest]::Create("$vcurl")
    # Get Thumbprint + add colons for a valid Thumbprint
    $destVCThumbprint = ($endpoint_request.ServicePoint.Certificate.GetCertHashString()) -replace '(..(?!$))','$1:'

    # Source VM to migrate
    $vm_view = Get-View (Get-VM -Server $sourcevc -Name $vm) -Property Config.Hardware.Device
    $src_vm_tags = @(get-TagAssignment -server $sourcevc -entity (Get-VM -Server $sourcevc -Name $vm)) 

    
    # Determine the destination datastore to migrate VM to
    # If you passed a datastore string we will use it here instead of figuring out the current location of disks.
    if($datastore -eq $null){
        $datastore_view = (Get-VMHost -Server $destVC -Name $vmhost | Get-Datastore -Server $destVC -Name $datastore)
        #Add the datastore to the relocation spec object
        $spec.datastore = $datastore_view.Id
    }
    else{
        # No datastore was passed so we need to build the move spec with the current disk information
        $sourceDisks = $vm_view.Config.Hardware.Device | where {$_ -is [vmware.vim.virtualdisk]}
        $VMXDestinationDisk = ($vm_view.Config.Hardware.Device | where {$_ -is [vmware.vim.virtualdisk]}) | where {$_.DeviceInfo.Label -eq "Hard disk 1"}
        $numberOfDisks = @($sourceDisks).Length

        #Convert source VC VMX datastore backing into target VC datastore backing
        $sourceVMXBacking = "Datastore-"+$VMXDestinationDisk.Backing.Datastore.Value
        $destVMXBacking = get-datastore -server $destVC (get-datastore -server $sourceVC -id $sourceVMXBacking | select name -ExpandProperty name -Unique) | select id -ExpandProperty id -Unique
        $destVMXBacking = $destVMXBacking.substring(10)
 
        $spec.datastore = New-Object VMware.Vim.ManagedObjectReference
        $spec.datastore.type = “Datastore”
        $spec.datastore.Value = $destVMXBacking
 
        #Specs to make our disks stay where they are
        $spec.disk = New-Object VMware.Vim.VirtualMachineRelocateSpecDiskLocator[] ($numberOfDisks)
        $i=0
        Foreach($disk in $sourceDisks) {
            #Add the string "Datastore" before the ID to be able to search for the datastore by ID
            $sourceDiskBacking = "Datastore-"+$disk.Backing.Datastore.Value      
            
            #Convert source VC datastore backing into target VC datastore backing
            $destDiskBacking = get-datastore -server $destVC (get-datastore -server $sourceVC -id $sourceDiskBacking | select name -ExpandProperty name -Unique) | select id -ExpandProperty id -Unique
            
            #Strip off the first "datastore" in the string
            $destDiskBacking = $destDiskBacking.substring(10)
            
            $spec.disk[$i] = New-Object VMware.Vim.VirtualMachineRelocateSpecDiskLocator
            $spec.disk[$i].diskId = $disk.Key
            $spec.disk[$i].datastore = New-Object VMware.Vim.ManagedObjectReference
            $spec.disk[$i].datastore.type = “Datastore”
            $spec.disk[$i].datastore.Value = $destDiskBacking
            $i++
        }
    }

    # Dest Cluster to migrate VM to
    $cluster_view = (Get-Cluster -Server $destVC -Name $cluster)

    # Dest ESXi host to migrate VM to
    $vmhost_view = (Get-VMHost -Server $destVC -Name $vmhost)

    # Find all Etherenet Devices for given VM which
    # we will need to change its network at the destination
    $vmNetworkAdapters = @()
    $devices = $vm_view.Config.Hardware.Device
    foreach ($device in $devices) {
        if($device -is [VMware.Vim.VirtualEthernetCard]) {
            $vmNetworkAdapters += $device
        }
    }

    # Relocate Spec for Migration
    $spec.host = $vmhost_view.Id
    $spec.pool = $cluster_view.ExtensionData.ResourcePool

    # Service Locator for the destination vCenter Server
    # regardless if its within same SSO Domain or not
    $service = New-Object VMware.Vim.ServiceLocator
    $credential = New-Object VMware.Vim.ServiceLocatorNamePassword
    $credential.username = $destVCusername
    $credential.password = $destVCpassword
    $service.credential = $credential
    $service.instanceUuid = $destVCConn.InstanceUuid
    $service.sslThumbprint = $destVCThumbprint
    $service.url = "https://$destVC"
    $spec.service = $service

    # Create VM spec depending if destination networking
    # is using Distributed Virtual Switch (VDS) or
    # is using Virtual Standard Switch (VSS)
    $count = 0
    if($switchtype -eq "vds") {
        foreach ($vmNetworkAdapter in $vmNetworkAdapters) {
            if($vmnetworks -eq $null -and $switch -ne $null){
                #Set VDS variable to the string for the destination switch
                $sourceVDS = $switch
                $sourceDVPG = Get-VDSwitch -server $sourceVC $switch | Get-VDPortgroup -server $sourceVC | where {$_.key -eq $vmNetworkAdapter.backing.port.portgroupkey}
            }
            elseif($switch -eq $null -and $vmnetworks -ne $null){
                #Get current VDS name and set the portgroup to the passed in string
                $sourceVDS = Get-VDSwitch -server $sourceVC | where {$_.key -eq $vmNetworkAdapter.backing.port.switchuuid}
                $sourceDVPG = ($vmnetworks -split ",")[$count]
            }
            else{
                # Extract Source VDS and Portgroup names
                $sourceVDS = Get-VDSwitch -server $sourceVC | where {$_.key -eq $vmNetworkAdapter.backing.port.switchuuid}
                $sourceDVPG = $sourceVDS | Get-VDPortgroup -server $sourceVC | where {$_.key -eq $vmNetworkAdapter.backing.port.portgroupkey}
            }
            #Get the destination switch information
            $dvpg = Get-VDSwitch -server $destvc $sourceVDS.name | Get-VDPortgroup -Server $destvc -Name $sourceDVPG.name
            $vds_uuid = (Get-View -server $destvc $dvpg.ExtensionData.Config.DistributedVirtualSwitch).Uuid
            $dvpg_key = $dvpg.ExtensionData.Config.key

            # Device Change spec for VSS portgroup
            $dev = New-Object VMware.Vim.VirtualDeviceConfigSpec
            $dev.Operation = "edit"
            $dev.Device = $vmNetworkAdapter
            $dev.device.Backing = New-Object VMware.Vim.VirtualEthernetCardDistributedVirtualPortBackingInfo
            $dev.device.backing.port = New-Object VMware.Vim.DistributedVirtualSwitchPortConnection
            $dev.device.backing.port.switchUuid = $vds_uuid
            $dev.device.backing.port.portgroupKey = $dvpg_key
            $spec.DeviceChange += $dev
            $count++
        }
    }
    else {
        foreach ($vmNetworkAdapter in $vmNetworkAdapters) {
            if($vmnetworks -ne $null){
                #Set Portgroup variable to the string for the destination portgroup
                $sourcePG = ($vmnetworks -split ",")[$count]
            }
            else{
                $sourcePG = Get-VirtualSwitch -server $sourceVC -vmhost $sourceVMHost | Get-VirtualPortgroup -server $sourceVC | where {$_.key -eq $vmNetworkAdapter.backing.devicename}
            }
        
            # Device Change spec for VSS portgroup
            $dev = New-Object VMware.Vim.VirtualDeviceConfigSpec
            $dev.Operation = "edit"
            $dev.Device = $vmNetworkAdapter
            $dev.device.backing = New-Object VMware.Vim.VirtualEthernetCardNetworkBackingInfo
            $dev.device.backing.deviceName = $sourcePG.name
            $spec.DeviceChange += $dev
            $count++
         }
    }
    try{
        Write-Host "`nMigrating $vmname from $sourceVC to $destVC ...`n"

        # Issue Cross VC-vMotion
        $task = $vm_view.RelocateVM_Task($spec,"defaultPriority")
        $task1 = Get-Task -Id ("Task-$($task.value)") -server $sourceVC
        $task1 | Wait-Task -Verbose

        if($src_vm_tags.count -gt 0){
            Write-Host "`nAssigning tags to $vm on $destVC`n"
            foreach ($tag in $src_vm_tags){
                New-TagAssignment -tag (get-tag -Name $tag.tag.name -server $destVC) -entity (Get-VM -Server $destvc -Name $vm) -server $destVC
            }
        }
    }
    catch{
        Write-Host "There was some error trying to submit the move task." -ForegroundColor Red
    }
}

Set-StrictMode -version 2
$ErrorActionPreference = "Stop"

# Variables that must be defined

$importedVMList = get-content C:\vms_to_move.csv
$sourceVC = "sourceVC"
$sourceVCUsername = "administrator@vsphere.local"
$sourceVCPassword = "password1"
$destVC = "destinationVC"
$destVCUsername = "administrator@vsphere.local"
$destVCPassword = "password2"
$destClusterName = "TargetDRSCluster"
#Set the switchname variable to $null if the destination switch uses the same name as the source switch.  The script to determine the source switch name.   
#Set the switchname variable to the target switch name if the source switch name and target switch name differ
$switch = $null
#Switch type should be set to either "vds" or "vss"
$switchtype = "vds"
#Set the vmnetworkname variable to $null if the destination portgroup uses the same name as the source portgroup.  The script will determine the source portgroup name
#Set the vmnetworkname variable to the destination portgroup name if you want to set a destination network for ALL VMs.  Be careful!
$vmnetworkname = $null
#Set the datastore variable to $null to allow the script to determine the VM's current disk location and to create the move spec.
#Set the datastore to a string to move all VMs in $importedVMList to that datastore
$datastore = $null

# Connect to Source/Destination vCenter Server
$sourceVCConn = Connect-VIServer -Server $sourceVC -user $sourceVCUsername -password $sourceVCPassword
$destVCConn = Connect-VIServer -Server $destVC -user $destVCUsername -password $destVCpassword


foreach ($vmname in $importedVMList){
    Write-Host "`nNow evaluating $vmname to determine VM hardware version...`n" -ForegroundColor White
    $vmobject = get-vm $vmname -server $sourceVC
    $vmhostobject = get-cluster $destClusterName -server $destVC | get-vmhost | sort-object MemoryUsageGB | select -First 1
    if($vmhostobject.MemoryUsageGB + $vmobject.MemoryGB -gt $vmhostobject.MemoryTotalGB){
        Write-Error "`nCluster does not appear to have enough memory resources.`
                    Exiting script to allow for manual intervention.`n"
    }
    if($vmobject.version -eq "v4"){
        Write-Error "`nVM is hardware version 4.`
                    There appears to be a bug that will successfully move the VM but upon `
                    power-cycle or vMotion on the target side will lose the assigned port-group. `
                    This is a sanity check to make sure you don't lose connection to your VM at `
                    a random time post-move!"
    }
    Write-Verbose "The destination host will be $($vmhostobject).name"
    xMove-VM -sourcevc $sourceVCConn -destvc $destVCConn -VM $vmname -switchtype $switchtype -cluster $destClusterName -vmhost $vmhostobject.name -sourceVMHost $vmobject.vmHost
}

# Disconnect from Source/Destination VC
Disconnect-VIServer -Server $sourceVCConn -Confirm:$false
Disconnect-VIServer -Server $destVCConn -Confirm:$false
