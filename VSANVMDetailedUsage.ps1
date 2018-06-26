Function Get-VSANVMDetailedUsage {
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
        detailed usage for all or specific VMs running on VSAN
    .PARAMETER Cluster
        The name of a vSAN Cluster
    .PARAMETER VM
        The name of a VM to query specifically
    .EXAMPLE
        Get-VSANVMDetailedUsage -Cluster "VSAN-Cluster"
    .EXAMPLE
        Get-VSANVMDetailedUsage -Cluster "VSAN-Cluster" -VM "Ubuntu-SourceVM"
#>
    param(
        [Parameter(Mandatory=$true)][String]$Cluster,
        [Parameter(Mandatory=$false)][String]$VM
    )

    $ESXiHostUsername = ""
    $ESXiHostPassword = ""

    if($ESXiHostUsername -eq "" -or $ESXiHostPassword -eq "") {
        Write-Host -ForegroundColor Red "You did not configure the ESXi host credentials, please update `$ESXiHostUsername & `$ESXiHostPassword variables and try again"
        return
    }

    # Scope query within vSAN/vSphere Cluster
    $clusterView = Get-View -ViewType ClusterComputeResource -Property Name,Host -Filter @{"name"=$Cluster}
    if(!$clusterView) {
        Write-Host -ForegroundColor Red "Unable to find vSAN Cluster $cluster ..."
        break
    }

    # Retrieve list of ESXi hosts from cluster
    # which we will need to directly connect to use call VsanQueryObjectIdentities()
    $vmhosts = $clusterView.host

    $results = @()
    foreach ($vmhost in $vmhosts) {
        $vmhostView = Get-View $vmhost -Property Name
        $esxiConnection = Connect-VIServer -Server $vmhostView.name -User $ESXiHostUsername -Password $ESXiHostPassword

        $vos = Get-VSANView -Id "VsanObjectSystem-vsan-object-system" -Server $esxiConnection
        $identities = $vos.VsanQueryObjectIdentities($null,$null,$null,$false,$true,$true)

        $json = $identities.RawData|ConvertFrom-Json
        $jsonResults = $json.identities.vmIdentities

        foreach ($vmInstance in $jsonResults) {
            $identities = $vmInstance.objIdentities
            foreach ($identity in $identities | Sort-Object -Property "type") {
                # Retrieve the VM Name
                if($identity.type -eq "namespace") {
                    $vsanIntSys = Get-View (Get-VMHost -Server $esxiConnection).ExtensionData.ConfigManager.vsanInternalSystem
                    $attributes = ($vsanIntSys.GetVsanObjExtAttrs($identity.uuid)) | ConvertFrom-JSON

                    foreach ($attribute in $attributes | Get-Member) {
                        # crappy way to iterate through keys ...
                        if($($attribute.Name) -ne "Equals" -and $($attribute.Name) -ne "GetHashCode" -and $($attribute.Name) -ne "GetType" -and $($attribute.Name) -ne "ToString") {
                            $objectID = $attribute.name
                            $vmName = $attributes.$($objectID).'User friendly name'
                        }
                    }
                }

                # Convert B to GB
                $physicalUsedGB = [math]::round($identity.physicalUsedB/1GB, 2)
                $reservedCapacityGB = [math]::round($identity.reservedCapacityB/1GB, 2)

                # Build our custom object to store only the data we care about
                $tmp = [pscustomobject] @{
                    VM = $vmName
                    File = $identity.description;
                    Type = $identity.type;
                    physicalUsedGB = $physicalUsedGB;
                    reservedCapacityGB = $reservedCapacityGB;
                }

                # Filter out a specific VM if provided
                if($VM) {
                    if($vmName -eq $VM) {
                        $results += $tmp
                    }
                } else {
                    $results += $tmp
                }
            }
        }
        Disconnect-VIServer -Server $esxiConnection -Confirm:$false
    }
    $results | Format-Table
}