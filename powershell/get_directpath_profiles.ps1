$cluster = Get-Cluster $VICLUSTER

$dpManager = Get-View $global:DefaultVIServer.ExtensionData.Content.DirectPathProfileManager

$filterSpec = New-Object VMware.Vim.DirectPathProfileManagerFilterSpec
$filterSpec.clusters = @($cluster.ExtensionData.MoRef)

$dpProfiles = $dpManager.DirectPathProfileManagerList($filterSpec)

$dppResults = @()
foreach($dpProfile in $dpProfiles | Sort-Object -Property Name) {
    if($dpProfile.name -notmatch "unnamed-") {
        if($dpProfile.DeviceConfig.getType().Name -eq "DirectPathProfileManagerVirtualDeviceGroupDirectPathConfig") {
            $dgName = $dpProfile.DeviceConfig.DeviceGroupName
        } elseif($dpProfile.DeviceConfig.getType().Name -eq "DirectPathProfileManagerVmiopDirectPathConfig") {
            $dgName = $dpProfile.DeviceConfig.VgpuProfile
        } else {
            $dgName = "Other"
        }

        $tmp = [PSCustomObject] [ordered]@{
            DeviceGroupName = $dgName
            Vendor = $dpProfile.VendorName
        }
        $dppResults+=$tmp
    }
}

$dppResults | FT