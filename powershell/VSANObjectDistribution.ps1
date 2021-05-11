Function Get-VsanObjectDistribution {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.williamlam.com
     Twitter:       @lamw
        ===========================================================================
    .DESCRIPTION
        This function provides an overview of the distribution of vSAN Objects across
        a given vSAN Cluster
    .PARAMETER Cluster
        The name of a vSAN Cluster
    .PARAMETER ShowvSANID
        Outputs the vSAN UUID of the SSD Device in Diskgroup
    .PARAMETER ShowDiskID
        Outputs the Disk Canoical ID of the SSD Device in Diskgroup
    .EXAMPLE
        Get-VsanObjectDistribution -ClusterName "VSAN-Cluster-6.5"
    .EXAMPLE
        Get-VsanObjectDistribution -ClusterName "VSAN-Cluster-6.5" -ShowDiskID $true
#>
    param(
        [Parameter(Mandatory=$true)][String]$ClusterName,
        [Parameter(Mandatory=$false)][Boolean]$ShowvSANID,
        [Parameter(Mandatory=$false)][Boolean]$ShowDiskID
    )

    Function Get-VSANDiskMapping {
        param(
            [Parameter(Mandatory=$true)]$vmhost
        )
        $vsanSystem = Get-View ($vmhost.ExtensionData.ConfigManager.VsanSystem)
        $vsanDiskMappings = $vsanSystem.config.storageInfo.diskMapping

        $diskGroupCount = 1
        $diskGroupObjectCount = 0
        $diskGroupObjectSize = 0
        $diskGroupMappings = @{}
        foreach ($disk in $vsanDiskMappings) {
            $hdds = $disk.nonSsd
            foreach ($hdd in $hdds) {
                $diskHDD = $hdd.VsanDiskInfo.VsanUuid
                if($diskInfo[$diskHDD]) {
                    $diskGroupObjectCount += $diskInfo[$diskHDD].totalComponents
                    $diskGroupObjectSize += $diskInfo[$diskHDD].used
                    $global:clusterTotalObjects += $diskInfo[$diskHDD].totalComponents
                    $global:clusterTotalObjectSize += $diskInfo[$diskHDD].used
                }
            }
            $diskGroupObj = [pscustomobject] @{
                numObjects = $diskGroupObjectCount;
                used = $diskGroupObjectSize;
                vsanID = $disk.Ssd.VsanDiskInfo.VsanUuid;
                diskID = $disk.Ssd.canonicalName;
            }
            $diskGroupMappings.add($diskGroupCount,$diskGroupObj)

            $diskGroupObjectCount = 0
            $diskGroupObjectSize = 0
            $diskGroupCount+=1
        }
        $global:clusterResults.add($vmhost.name,$diskGroupMappings)
    }

    Function BuildDiskInfo {
        $randomVmhost = Get-Cluster -Name $ClusterName | Get-VMHost | Select -First 1
        $vsanIntSys = Get-View ($randomVmhost.ExtensionData.ConfigManager.VsanInternalSystem)
        $results = $vsanIntSys.QueryPhysicalVsanDisks($null)
        $json = $results | ConvertFrom-Json


        foreach ($line in $json | Get-Member -MemberType NoteProperty) {
            $tmpObj = [pscustomobject] @{
                totalComponents = $json.$($line.Name).numTotalComponents
                dataComponents = $json.$($line.Name).numDataComponents
                witnessComponents = ($json.$($line.Name).numTotalComponents - $json.$($line.Name).numDataComponents)
                capacity = $json.$($line.Name).capacity
                used = $json.$($line.Name).physCapacityUsed
            }
            $diskInfo.Add($json.$($line.Name).uuid,$tmpObj)
        }
    }

    $cluster = Get-Cluster -Name $ClusterName -ErrorAction SilentlyContinue
    if($cluster -eq $null) {
        Write-Host -ForegroundColor Red "Error: Unable to find vSAN Cluster $ClusterName ..."
        break
    }

    $global:clusterResults = @{}
    $global:clusterTotalObjects =  0
    $global:clusterTotalObjectSize = 0
    $diskInfo = @{}
    BuildDiskInfo

    foreach ($vmhost in $cluster | Get-VMHost) {
        Get-VSANDiskMapping -vmhost $vmhost
    }

    Write-Host "`nTotal vSAN Components: $global:clusterTotalObjects"
    $size = [math]::Round(($global:clusterTotalObjectSize / 1GB),2)
    Write-Host "Total vSAN Components Size: $size GB"

    foreach ($vmhost in $global:clusterResults.keys | Sort-Object) {
        Write-Host "`n"$vmhost
        foreach ($diskgroup in $global:clusterResults[$vmhost].keys | Sort-Object) {
            if($ShowvSANID) {
                $diskID = $clusterResults[$vmhost][$diskgroup].vsanID
            } else {
                $diskID = $clusterResults[$vmhost][$diskgroup].diskID
            }

            Write-Host "`tDiskgroup $diskgroup (SSD: $diskID)"

            $numbOfObjects = $clusterResults[$vmhost][$diskgroup].numObjects
            $objPercentage = [math]::Round(($numbOfObjects / $global:clusterTotalObjects) * 100,2)
            Write-host "`t`tComponents: $numbOfObjects ($objPercentage%)"

            $objectsUsed = $clusterResults[$vmhost][$diskgroup].used
            $objectsUsedRounded = [math]::Round(($clusterResults[$vmhost][$diskgroup].used / 1GB),2)
            $usedPertcentage =[math]::Round(($objectsUsed / $global:clusterTotalObjectSize) * 100,2)
            Write-host "`t`tSize: $objectsUsedRounded GB ($usedPertcentage%)"
        }
    }
}
