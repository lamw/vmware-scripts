Function Get-VSANHclInfo {
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
        the last time vSAN HCL was updated + HCL Health if HCL DB > 90days
    .PARAMETER Cluster
        The name of a vSAN Cluster
    .EXAMPLE
        Get-VSANHclInfo -Cluster Palo-Alto
#>
    param(
        [Parameter(Mandatory=$true)][String]$Cluster
    )

    # Scope query within vSAN/vSphere Cluster
    $clusterView = Get-Cluster -Name $Cluster -ErrorAction SilentlyContinue
    if($clusterView) {
        $clusterMoref = $clusterView.ExtensionData.MoRef
    } else {
        Write-Host -ForegroundColor Red "Unable to find vSAN Cluster $cluster ..."
        break
    }
    
    $vchs = Get-VsanView -Id VsanVcClusterHealthSystem-vsan-cluster-health-system
    $results = $vchs.VsanVcClusterGetHclInfo($clusterMoref,$null,$null,$null)
    $results | Select HclDbLastUpdate, HclDbAgeHealth
}