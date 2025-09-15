$cluster = Get-Cluster $VICLUSTER

$dpMgr = Get-View $global:DefaultVIServer.ExtensionData.Content.DirectPathProfileManager

$utilizationResults = @()
$targetSpec = New-Object VMware.Vim.DirectPathProfileManagerTargetCluster
$targetSpec.Cluster = $cluster.ExtensionData.MoRef

$utilizations = $dpMgr.DirectPathProfileManagerQueryCapacity($targetSpec,$null)
foreach($utilization in $utilizations | Sort-Object -Property Name) {
    $tmp = [PSCustomObject] [ordered]@{
        Name = $utilization.Profile.Name
        Consumed = $utilization.Consumed
        Remaining = $utilization.Remaining
        Maximum = $utilization.max
    }
    $utilizationResults+=$tmp
}

$utilizationResults | FT