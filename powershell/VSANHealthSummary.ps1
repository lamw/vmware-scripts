Function Get-VsanHealthSummary {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.virtuallyghetto.com
     Twitter:       @lamw
        ===========================================================================
    .DESCRIPTION
        This function demonstrates the use of vSAN Management API to retrieve
        the same information provided by the RVC command "vsan.health.health_summary"
    .PARAMETER Cluster
        The name of a vSAN Cluster
    .EXAMPLE
        Get-VsanHealthSummary -Cluster VSAN-Cluster
#>
    param(
        [Parameter(Mandatory=$true)][String]$Cluster
    )
    $vchs = Get-VSANView -Id "VsanVcClusterHealthSystem-vsan-cluster-health-system"
    $cluster_view = (Get-Cluster -Name $Cluster).ExtensionData.MoRef
    $results = $vchs.VsanQueryVcClusterHealthSummary($cluster_view,$null,$null,$true,$null,$null,'defaultView')
    $healthCheckGroups = $results.groups

    $healthCheckResults = @()
    foreach($healthCheckGroup in $healthCheckGroups) {
        switch($healthCheckGroup.GroupHealth) {
            red {$healthStatus = "error"}
            yellow {$healthStatus = "warning"}
            green {$healthStatus = "passed"}
        }
        $healtCheckGroupResult = [pscustomobject] @{
            HealthCHeck = $healthCheckGroup.GroupName
            Result = $healthStatus
        }
        $healthCheckResults+=$healtCheckGroupResult
    }
    Write-Host "`nOverall health:" $results.OverallHealth "("$results.OverallHealthDescription")"
    $healthCheckResults
}