# Author: William Lam
# Blog: www.williamlam.com
# Description: Script to add a new VMDK w/the MultiWriter Flag enabled in vSphere 6.x
# Reference: http://www.williamlam.com/2015/10/new-method-of-enabling-multiwriter-vmdk-flag-in-vsphere-6-0-update-1.html

$vcname = "192.168.1.51"
$vcuser = "administrator@vghetto.local"
$vcpass = "VMware1!"

$vmName = "Multi-Writer-VM"
# Syntax: [datastore-name] vm-home-dir/vmdk-name.vmdk
# Use (Get-VM -Name "Multi-Writer-VM").ExtensionData.Layout.Disk to help identify VM-Home-Dir
$vmdkFileNamePath = "[vsanDatastore] f2d16e57-7ecf-bf9f-8a6a-b8aeed7c9e96/Multi-Writer-VM-1.vmdk"
$diskSizeGB = 5
$diskControllerNumber = 0
$diskUnitNumber = 1

#### DO NOT EDIT BEYOND HERE ####

$server = Connect-VIServer -Server $vcname -User $vcuser -Password $vcpass

# Retrieve VM and only its Devices
$vm = Get-View -Server $server -ViewType VirtualMachine -Property Name,Config.Hardware.Device -Filter @{"Name" = $vmName}

# Convert GB to KB
$diskSizeInKB = (($diskSizeGB * 1024 * 1024 * 1024)/1KB)
$diskSizeInKB = [Math]::Round($diskSizeInKB,4,[MidPointRounding]::AwayFromZero)

# Array of Devices on VM
$vmDevices = $vm.Config.Hardware.Device

# Find the SCSI Controller we care about
foreach ($device in $vmDevices) {
	if($device -is [VMware.Vim.VirtualSCSIController] -and $device.BusNumber -eq $diskControllerNumber) {
		$diskControllerKey = $device.key
        break
	}
}

# Create VM Config Spec to add new VMDK & Enable Multi-Writer Flag
$spec = New-Object VMware.Vim.VirtualMachineConfigSpec
$spec.deviceChange = New-Object VMware.Vim.VirtualDeviceConfigSpec
$spec.deviceChange[0].operation = 'add'
$spec.DeviceChange[0].FileOperation = 'create'
$spec.deviceChange[0].device = New-Object VMware.Vim.VirtualDisk
$spec.deviceChange[0].device.key = -1
$spec.deviceChange[0].device.ControllerKey = $diskControllerKey
$spec.deviceChange[0].device.unitNumber = $diskUnitNumber
$spec.deviceChange[0].device.CapacityInKB = $diskSizeInKB
$spec.DeviceChange[0].device.backing = New-Object VMware.Vim.VirtualDiskFlatVer2BackingInfo
$spec.DeviceChange[0].device.Backing.fileName = $vmdkFileNamePath
$spec.DeviceChange[0].device.Backing.diskMode = "persistent"
$spec.DeviceChange[0].device.Backing.eagerlyScrub = $True
$spec.DeviceChange[0].device.Backing.Sharing = "sharingMultiWriter"

Write-Host "`nAdding new VMDK w/capacity $diskSizeGB GB to VM: $vmname"
$task = $vm.ReconfigVM_Task($spec)
$task1 = Get-Task -Id ("Task-$($task.value)")
$task1 | Wait-Task

Disconnect-VIServer $server -Confirm:$false
