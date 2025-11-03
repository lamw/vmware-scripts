Function Get-VsanClusterShutdownPrecheckResults {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Blog:          www.williamlam.com
        ===========================================================================
    .DESCRIPTION
        This function demonstrates the use of vSAN Management API to retrieve
        the "clusterPowerOffPrecheck" Perspective results
    .PARAMETER Cluster
        The name of a vSAN Cluster
    .EXAMPLE
        Get-VsanClusterShutdownPrecheckResults -Cluster VCF-Mgmt-Cluster
#>
    param(
        [Parameter(Mandatory=$true)][String]$Cluster
    )
    $vchs = Get-VSANView -Id "VsanVcClusterHealthSystem-vsan-cluster-health-system"
    $cluster_view = (Get-Cluster -Name $Cluster).ExtensionData.MoRef
    $results = $vchs.VsanQueryVcClusterHealthSummary($cluster_view,$null,$null,$false,$null,$null,'clusterPowerOffPrecheck',$null,$null)
    $shutdownGroupTests = $results.Groups | where {$_.GroupId -eq "com.vmware.vsan.health.test.clusterpower"}

    $vmsNotShutdown = @()
    if($shutdownGroupTests.GroupHealth -eq "red") {
        $shutdownGroupTest = $shutdownGroupTests.GroupTests | where {$_.TestId -eq "com.vmware.vsan.health.test.allvmsshutdown"}
        if($shutdownGroupTest.TestHealth -eq "red") {
            $testDetailValues = $shutdownGroupTest.TestDetails.Rows.Values
            foreach ($testDetailValue in $testDetailValues) {
                $vmMoref = $testDetailValue.replace("mor:ManagedObjectReference:VirtualMachine:","")

                $vm = New-Object VMware.Vim.ManagedObjectReference
                $vm.Type = "VirtualMachine"
                $vm.Value = $vmMoref

                $vmsNotShutdown += (Get-View $vm).Name
            }
        }
    }
    Write-Host
    $vmsNotShutdown | Sort-Object
    Write-Host
}