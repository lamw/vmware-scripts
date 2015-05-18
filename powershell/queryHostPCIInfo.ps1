# Author: William Lam
# Website: www.virtuallyghetto
# Product: VMware vSphere
# Description: Script to extract ESXi PCI Device details such as Name, Vendor, VID, DID & SVID
# Reference: http://www.virtuallyghetto.com/2015/05/extracting-vid-did-svid-from-pci-devices-in-esxi-using-vsphere-api.html

$server = Connect-VIServer -Server 192.168.1.60 -User administrator@vghetto.local -Password VMware1!

$vihosts = Get-View -Server $server -ViewType HostSystem -Property Name,Hardware.PciDevice

$devices_results = @()

foreach ($vihost in $vihosts) {
	$pciDevices = $vihost.Hardware.PciDevice
	foreach ($pciDevice in $pciDevices) {
		$details = "" | select HOST, DEVICE, VENDOR, VID, DID, SVID
		$vid = [String]::Format("{0:x}", $pciDevice.VendorId)
		$did = [String]::Format("{0:x}", $pciDevice.DeviceId)
		$svid = [String]::Format("{0:x}", $pciDevice.SubVendorId)		

		$details.HOST = $vihost.Name
		$details.DEVICE = $pciDevice.DeviceName
		$details.VENDOR = $pciDevice.VendorName
		$details.VID = $vid
		$details.DID = $did
		$details.SVID = $svid
		$devices_results += $details
	}
}

$devices_results

Disconnect-VIServer $server -Confirm:$false