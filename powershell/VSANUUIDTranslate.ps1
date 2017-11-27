Function Get-VSANVMToUUID {
    <#
        .NOTES
        ===========================================================================
         Created by:    William Lam
         Organization:  VMware
         Blog:          www.virtuallyghetto.com
         Twitter:       @lamw
            ===========================================================================
        .DESCRIPTION
            This function demonstrates the use of the vSAN Management API to retrieve
            the vSAN UUID given a VM Name
        .PARAMETER Cluster
            The name of a vSAN Cluster
        .EXAMPLE
            Get-VSANVMToUUID -Cluster VSAN-Cluster -VMName Embedded-vCenter-Server-Appliance
    #>
        param(
            [Parameter(Mandatory=$true)][String]$Cluster,
            [Parameter(Mandatory=$true)][String]$VMName
        )

        $clusterView = Get-Cluster -Name $Cluster -ErrorAction SilentlyContinue
        if($clusterView) {
            $clusterMoRef = $clusterView.ExtensionData.MoRef
            $vmMoRef = "VirtualMachine-" + (Get-VM -Name $VMName).ExtensionData.MoRef.Value
        } else {
            Write-Host -ForegroundColor Red "Unable to find vSAN Cluster $cluster ..."
            break
        }

        $vsanClusterObjectSys = Get-VsanView -Id VsanObjectSystem-vsan-cluster-object-system
        $results = $vsanClusterObjectSys.VsanQueryObjectIdentities($clusterMoRef,$null,$null,$false,$true,$false)

        $vmObjectInfo = @()
        foreach ($result in $results.Identities) {
            if($result.Vm -eq $vmMoRef) {
                $tmp = [pscustomobject] @{
                    Type=$result.type;
                    UUID=$result.uuid;
                    File=$result.description
                }
                $vmObjectInfo+=$tmp
            }
        }
        $vmObjectInfo | Sort-Object -Property Type,File
    }

Function Get-VSANUUIDToVM {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.virtuallyghetto.com
     Twitter:       @lamw
        ===========================================================================
    .DESCRIPTION
        This function demonstrates the use of the vSAN Management API to retrieve
        the VM Name/Object given vSAN UUID
    .PARAMETER VSANObjectID
        List of vSAN Object UUIDs
    .PARAMETER Cluster
        The name of a vSAN Cluster
    .EXAMPLE
        Get-VSANUUIDToVM -VSANObjectID @("6a887f59-6448-08f2-155d-b8aeed7c9e96") -Cluster VSAN-Cluster
#>
    param(
        [Parameter(Mandatory=$true)][String]$Cluster,
        [Parameter(Mandatory=$true)][String[]]$VSANObjectID
    )

    $clusterView = Get-Cluster -Name $Cluster -ErrorAction SilentlyContinue
    if($clusterView) {
        $vmhost = ($clusterView | Get-VMHost) | select -First 1
        $vsanIntSys = Get-View $vmhost.ExtensionData.configManager.vsanInternalSystem
    } else {
        Write-Host -ForegroundColor Red "Unable to find vSAN Cluster $cluster ..."
        break
    }

    $results = @()
    $jsonResult = ($vsanIntSys.GetVsanObjExtAttrs($VSANObjectID)) | ConvertFrom-JSON
    foreach ($object in $jsonResult | Get-Member) {
        # crappy way to iterate through keys ...
        if($($object.Name) -ne "Equals" -and $($object.Name) -ne "GetHashCode" -and $($object.Name) -ne "GetType" -and $($object.Name) -ne "ToString") {
            $objectID = $object.name
            $jsonResult.$($objectID)
        }
    }
}