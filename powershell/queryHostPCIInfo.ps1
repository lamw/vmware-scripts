# Author: William Lam
# Website: www.williamlam.com
# Description: Script to extract ESXi PCI Device details such as Name, Vendor, VID, DID & SVID
# Reference: http://www.williamlam.com/2015/05/extracting-vid-did-svid-from-pci-devices-in-esxi-using-vsphere-api.html

$vmhost = Get-View -ViewType HostSystem -Property Name,Hardware.PciDevice -Filter @{"name"="mgmt-esx01.vcf.lab"}
$pciDevices = $vmhost.Hardware.PciDevice

# Exclude any devices you do not wish to see, partial or full match supported
$excludeDevices = @("<class> System peripheral","<class> Performance counters","<class> PCI bridge","<class> ISA bridge","Series Chipset Family","Ice Lake RAS","Ice Lake IEH","MSM","UPI","Memory Map/VT-d","Mesh 2 PCIe")

$deviceResults = @()
foreach ($pciDevice in $pciDevices) {
        $vid = [String]::Format("{0:x}", $pciDevice.VendorId)
        $did = [String]::Format("{0:x}", $pciDevice.DeviceId)
        $svid = [String]::Format("{0:x}", $pciDevice.SubVendorId)

    if(-not ($excludeDevices | Where-Object { $pciDevice.DeviceName -like "*$_*" }) -and $svid -ne 0) {
        $tmp = [pscustomobject] [ordered]@{
            Vendor = $pciDevice.VendorName
            Device = $pciDevice.DeviceName
            VID = $vid
            DID = $did
            SVID = $svid
        }
        $deviceResults+=$tmp
    }
}

$deviceResults | FT