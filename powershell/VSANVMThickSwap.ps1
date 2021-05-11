Function Get-VSANVMThickSwap {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.williamlam.com
     Twitter:       @lamw
        ===========================================================================
    .DESCRIPTION
        This function demonstrates the use of vSAN Management API to retrieve
        all VMs that have "thick" provisioned VM Swap
    .PARAMETER Cluster
        The name of a vSAN Cluster
    .EXAMPLE
        Get-VSANVMThickSwap -Cluster VCSA-Cluster
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

    # Retrieve random ESXi host within vSAN/vSphere Cluster to access vSAN Internal System Object
    $randomVMhost = $clusterView | Get-VMHost | Get-Random
    $vsanIntSys = Get-View ($randomVMhost.ExtensionData.ConfigManager.VsanInternalSystem)
   
    # Create mapping of VMs within vSAN/vSphere Cluster to their associated MoRef
    $vmMoRefIdMapping = @{}
    $vms = Get-Cluster -Name $Cluster | Get-VM
    foreach ($vm in $vms) {
        $vmMoRefIdMapping[$vm.ExtensionData.MoRef] = $vm.name
    }
    
    # Retrieve all vSAN vmswap objects
    $vos = Get-VSANView -Id "VsanObjectSystem-vsan-cluster-object-system" 
    $results = $vos.VsanQueryObjectIdentities($clusterMoref,$null,'vmswap',$false,$true,$false)

    # Process results and look for vmswaps that are "thick" and return array of VM names
    $vmsWithThickSwap = @()
    foreach ($result in $results.Identities) {
        $vsanuuid = $result.uuid
        $vmMoref = $result.vm
        $vmName = $vmMoRefIdMapping[$vmMoref]
        $json = $vsanIntSys.GetVsanObjExtAttrs(@($vsanuuid)) | ConvertFrom-Json
        foreach ($line in $json | Get-Member) {
            $allocationType = $json.$($line.Name).'Allocation type'
            if($allocationType -eq "Zeroed thick") {
                $vmsWithThickSwap +=$vmName
            }
        }
    }
    $vmsWithThickSwap
}
