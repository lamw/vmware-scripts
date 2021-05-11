Function Get-VSANHealthChecks {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.williamlam.com
     Twitter:       @lamw
        ===========================================================================
    .DESCRIPTION
        This function retreives all available vSAN Health Checks
    .PARAMETER Cluster
        The name of a vSAN Cluster
    .EXAMPLE
        Get-VSANHealthChecks
#>
    $vchs = Get-VSANView -Id "VsanVcClusterHealthSystem-vsan-cluster-health-system"
    $vchs.VsanQueryAllSupportedHealthChecks() | Select TestId, TestName | Sort-Object -Property TestId
}

Function Get-VSANSilentHealthChecks {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.williamlam.com
     Twitter:       @lamw
        ===========================================================================
    .DESCRIPTION
        This function retreives the list of vSAN Health CHecks that have been silenced
    .PARAMETER Cluster
        The name of a vSAN Cluster
    .EXAMPLE
        Get-VSANSilentHealthChecks -Cluster VSAN-Cluster
#>
    param(
        [Parameter(Mandatory=$true)][String]$Cluster
    )
    $vchs = Get-VSANView -Id "VsanVcClusterHealthSystem-vsan-cluster-health-system"
    $cluster_view = (Get-Cluster -Name $Cluster).ExtensionData.MoRef
    $results = $vchs.VsanHealthGetVsanClusterSilentChecks($cluster_view)

    Write-Host "`nvSAN Health Checks Currently Silenced:`n"
    $results
}

Function Set-VSANSilentHealthChecks {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.williamlam.com
     Twitter:       @lamw
        ===========================================================================
    .DESCRIPTION
        This function retreives the vSAN software version for both VC/ESXi
    .PARAMETER Cluster
        The name of a vSAN Cluster
    .PARAMETER Test
        The list of vSAN Health CHeck IDs to silence or re-enable
    .EXAMPLE
        Set-VSANSilentHealthChecks -Cluster VSAN-Cluster -Test controlleronhcl -Disable
    .EXAMPLE
        Set-VSANSilentHealthChecks -Cluster VSAN-Cluster -Test controlleronhcl,controllerfirmware -Disable
    .EXAMPLE
        Set-VSANSilentHealthChecks -Cluster VSAN-Cluster -Test controlleronhcl -Enable
    .EXAMPLE
        Set-VSANSilentHealthChecks -Cluster VSAN-Cluster -Test controlleronhcl,controllerfirmware -Enable
#>
    param(
        [Parameter(Mandatory=$true)][String]$Cluster,
        [Parameter(Mandatory=$true)][String[]]$Test,
        [Switch]$Enabled,
        [Switch]$Disabled
    )
    $vchs = Get-VSANView -Id "VsanVcClusterHealthSystem-vsan-cluster-health-system"
    $cluster_view = (Get-Cluster -Name $Cluster).ExtensionData.MoRef

    if($Enabled) {
        $vchs.VsanHealthSetVsanClusterSilentChecks($cluster_view,$null,$Test)
    } else {
        $vchs.VsanHealthSetVsanClusterSilentChecks($cluster_view,$Test,$null)
    }
}
