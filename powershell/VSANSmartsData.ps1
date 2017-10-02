Function Get-VSANSmartsData {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.virtuallyghetto.com
     Twitter:       @lamw
        ===========================================================================
    .DESCRIPTION
        This function retreives SMART drive data using new vSAN
        Management 6.6 API. This can also be used outside of vSAN
        to query existing SSD devices not being used for vSAN.
    .PARAMETER Cluster
        The name of a vSAN Cluster
    .EXAMPLE
        Get-VSANSmartsData -Cluster VSAN-Cluster
#>
   param(
        [Parameter(Mandatory=$false)][String]$Cluster
    )

    if($global:DefaultVIServer.ExtensionData.Content.About.ApiType -eq "VirtualCenter") {
        if(!$cluster) {
            Write-Host "Cluster property is required when connecting to vCenter Server"
            break
        }

        $vchs = Get-VSANView -Id "VsanVcClusterHealthSystem-vsan-cluster-health-system"
        $cluster_view = (Get-Cluster -Name $Cluster).ExtensionData.MoRef
        $result = $vchs.VsanQueryVcClusterSmartStatsSummary($cluster_view)
    } else {
        $vhs = Get-VSANView -Id "HostVsanHealthSystem-ha-vsan-health-system"
        $result = $vhs.VsanHostQuerySmartStats($null,$true)
    }

    $vmhost = $result.Hostname
    $smartsData = $result.SmartStats

    Write-Host "`nESXi Host: $vmhost`n"
    foreach ($data in $smartsData) {
        if($data.stats) {
            $stats = $data.stats
            Write-Host $data.disk

            $smartsResults = @()
            foreach ($stat in $stats) {
                $statResult = [pscustomobject] @{
                    Parameter = $stat.Parameter;
                    Value =$stat.Value;
                    Threshold = $stat.Threshold;
                    Worst = $stat.Worst
                }
                $smartsResults+=$statResult
            }
            $smartsResults | Format-Table
        }
    }
}