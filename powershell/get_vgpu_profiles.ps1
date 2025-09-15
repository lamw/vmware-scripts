$cluster = Get-Cluster $VICLUSTER

$envBrowser = Get-View $cluster.ExtensionData.EnvironmentBrowser

$directPathDevices = $envBrowser.QueryConfigTarget($null).DynamicPassthrough
$vgpuDevices =  $envBrowser.QueryConfigTarget($null).VgpuProfileInfo
$deviceGroupDevices = $envBrowser.QueryConfigTarget($null).VendorDeviceGroupInfo

$deviceResults = @()
foreach($device in $directPathDevices) {
    $tmp = [PSCustomObject] [ordered]@{
        Name = $device.DeviceName
        AccessType = "Dynamic DirectPath IO"
    }
    $deviceResults+=$tmp
}

foreach($device in $vgpuDevices) {
    $vendorId = $device.DeviceVendorId

    $tmp = [PSCustomObject] [ordered]@{
        Name = $device.ProfileName
        AccessType = "NVIDIA GRID vGPU"
    }
    $deviceResults+=$tmp
}

foreach($device in $deviceGroupDevices) {
    $tmp = [PSCustomObject] [ordered]@{
        Name = $device.DeviceGroupName
        AccessType = "Group"
    }
    $deviceResults+=$tmp
}

$deviceResults | Sort-Object -Property Name | FT