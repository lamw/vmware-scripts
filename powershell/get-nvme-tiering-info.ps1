
$clusterName = "Cluster"

$results = @()
foreach ($vmhost in Get-Cluster -Name $clusterName | Get-VMhost | Sort-Object -Property Name) {
    $tieringType = $vmhost.ExtensionData.Hardware.memoryTieringType

    $totalMemory = [math]::round($vmhost.ExtensionData.Hardware.MemorySize /1GB,2).ToString() + " GB"
    $tieringRatio = ($vmhost | Get-AdvancedSetting Mem.TierNvmePct).Value.toString() + "%"

    $tieringEnabled = $false
    if($tieringType -eq "softwareTiering") {
        $tieringEnabled = $true

        $dramTotal = [math]::round(($vmhost.ExtensionData.Hardware.MemoryTierInfo | where {$_.Name -eq "DRAM"}).Size /1GB,2).ToString() + " GB"
        $nvmeTotal = [math]::round(($vmhost.ExtensionData.Hardware.MemoryTierInfo | where {$_.Name -eq "NVMe"}).Size /1GB,2).ToString() + " GB"

        $storageSystem = Get-View $vmhost.ExtensionData.ConfigManager.StorageSystem
        $nvmeDevice = ($storageSystem.StorageDeviceInfo.ScsiLun | where {$_.UsedByMemoryTiering -eq $true}).CanonicalName

    } else {
        $dramTotal = $totalMemory
        $nvmeTotal = 0
        $nvmeDevice = "N/A"
    }

    $tmp = [pscustomobject] @{
        VMHost = $vmhost.Name
        TieringEnabled = $tieringEnabled
        TieringRatio = $tieringRatio
        DRAMMemory = $dramTotal
        NVMeMemory = $nvmeTotal
        TotalSystemMemory = $totalMemory
        NVMeDevice = $nvmeDevice
    }
    $results+=$tmp
}

$results | FT
