
Function Get-VMHardwareVersion {
    param(
        [Parameter(Mandatory=$true)][String]$ClusterName
    )

    $cluster = Get-Cluster $ClusterName
    $envBrowser = Get-View $cluster.ExtensionData.EnvironmentBrowser

    $envBrowser.QueryConfigOptionDescriptor().key
}

Function Get-VMHardwareConfig {
    param(
        [Parameter(Mandatory=$true)][String]$ClusterName,
        [Parameter(Mandatory=$true)][String]$VMHardwareVersion
    )

    $cluster = Get-Cluster $ClusterName
    $vmhost = $cluster | Get-VMHost | select -First 1
    $envBrowser = Get-View $cluster.ExtensionData.EnvironmentBrowser

    $vmHardwareConfigs = $envBrowser.QueryConfigOption($VMHardwareVersion,$vmhost.ExtensionData.MoRef)
    $vmHardwareConfigs.GuestOSDescriptor
}