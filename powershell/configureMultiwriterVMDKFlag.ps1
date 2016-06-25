# Author: William Lam
# Blog: www.virtuallyghetto.com
# Description: Script to enable MultiWriter VMDK flag in vSphere 6.x
# Reference: http://www.virtuallyghetto.com/2015/10/new-method-of-enabling-multiwriter-vmdk-flag-in-vsphere-6-0-update-1.html

$vcname = "192.168.1.150"
$vcuser = "administrator@vghetto.local"
$vcpass = "VMware1!"

$vmName = "vm-1"
$diskName = "Hard disk 2"

#### DO NOT EDIT BEYOND HERE ####

$server = Connect-VIServer -Server $vcname -User $vcuser -Password $vcpass

# Retrieve VM and only its Devices
$vm = Get-View -Server $server -ViewType VirtualMachine -Property Name,Config.Hardware.Device -Filter @{"Name" = $vmName}

# Array of Devices on VM
$vmDevices = $vm.Config.Hardware.Device

# Find the Virtual Disk that we care about
foreach ($device in $vmDevices) {
	if($device -is  [VMware.Vim.VirtualDisk] -and $device.deviceInfo.Label -eq $diskName) {
		$diskDevice = $device
		$diskDeviceBaking = $device.backing
		break
	}
}

# Create VM Config Spec to Edit existing VMDK & Enable Multi-Writer Flag
$spec = New-Object VMware.Vim.VirtualMachineConfigSpec
$spec.deviceChange = New-Object VMware.Vim.VirtualDeviceConfigSpec
$spec.deviceChange[0].operation = 'edit'
$spec.deviceChange[0].device = New-Object VMware.Vim.VirtualDisk
$spec.deviceChange[0].device = $diskDevice
$spec.DeviceChange[0].device.backing = New-Object VMware.Vim.VirtualDiskFlatVer2BackingInfo
$spec.DeviceChange[0].device.backing = $diskDeviceBaking
$spec.DeviceChange[0].device.Backing.Sharing = "sharingMultiWriter"

Write-Host "`nEnabling Multiwriter flag on on VMDK:" $diskName "for VM:" $vmname
$task = $vm.ReconfigVM_Task($spec)
$task1 = Get-Task -Id ("Task-$($task.value)")
$task1 | Wait-Task

Disconnect-VIServer $server -Confirm:$false
