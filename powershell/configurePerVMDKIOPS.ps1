# Author: William Lam
# Blog: www.virtuallyghetto.com
# Description: Script to configure per-VMDK IOPS Reservations on a VM in vSphere 6.0
# Reference: http://www.virtuallyghetto.com/2015/05/configuring-per-vmdk-iops-reservations-in-vsphere-6-0

$server = Connect-VIServer -Server 192.168.1.60 -User administrator@vghetto.local -Password VMware1!

# Fill out with your VM Name, Disk Label & IOPS Reservation
$vmName = "Photon"
$diskName = "Hard disk 1"
$iopsReservation = "2000"

### DO NOT EDIT BEYOND HERE ###

# Retrieve VM and only its Devices
$vm = Get-View -Server $server -ViewType VirtualMachine -Property Name,Config.Hardware.Device -Filter @{"Name" = $vmName}

# Array of Devices on VM
$vmDevices = $vm.Config.Hardware.Device

# Find the Virtual Disk that we care about
foreach ($device in $vmDevices) {
	if($device -is  [VMware.Vim.VirtualDisk] -and $device.deviceInfo.Label -eq $diskName) {
			$diskDevice = $device
			break
	}
}

# Create VM Config Spec
$spec = New-Object VMware.Vim.VirtualMachineConfigSpec
$spec.deviceChange = New-Object VMware.Vim.VirtualDeviceConfigSpec
$spec.deviceChange[0].operation = 'edit'
$spec.deviceChange[0].device = New-Object VMware.Vim.VirtualDisk
$spec.deviceChange[0].device = $diskDevice
$spec.deviceChange[0].device.storageIOAllocation.reservation = $iopsReservation
Write-Host "Configuring IOPS Reservation:" $iopsReservation "on VMDK:" $diskName "for VM:" $vmname
$vm.ReconfigVM($spec)

# Uncomment the following snippet if you wish to verify as part of the reconfiguration operation 

#$vm.UpdateViewData()
#$vmDevices = $vm.Config.Hardware.Device
#foreach ($device in $vmDevices) {
#	if($device -is  [VMware.Vim.VirtualDisk] -and $device.deviceInfo.Label -eq $diskName) {
#			$device.storageIOAllocation
#	}
#}

Disconnect-VIServer $server -Confirm:$false