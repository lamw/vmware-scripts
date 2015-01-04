# Author: William Lam
# Website: www.virtuallyghetto.com
# Product: VMware vSphere / VSAN
# Description: VSAN Flash/MD capacity report
# Reference: http://www.virtuallyghetto.com/2014/04/vsan-flashmd-capacity-reporting.html

$vcName = ""
$vcenter = Connect-VIServer $vcname -WarningAction SilentlyContinue

$vsanMaxConfigInfo = @()

$clusviews = Get-View -ViewType ClusterComputeResource -Property Name,ConfigurationEx,Host
foreach ($cluster in $clusviews) {
	if($cluster.ConfigurationEx.VsanConfigInfo.Enabled) {
		$vmhosts = $cluster.Host
        foreach ($vmhost in $vmhosts | Sort-Object -Property Name) {
			$vmhostView = Get-View $vmhost -Property Name,ConfigManager.VsanSystem,ConfigManager.VsanInternalSystem	
			$vsanSys = Get-View -Id $vmhostView.ConfigManager.VsanSystem
			$vsanIntSys = Get-View -Id $vmhostView.ConfigManager.VsanInternalSystem
		
			$vsanProps = @("owner","uuid","isSsd","capacity","capacityUsed","capacityReserved")
			$results = $vsanIntSys.QueryPhysicalVsanDisks($vsanProps)
			$vsanStatus = $vsanSys.QueryHostStatus()
				
			$json = $results | ConvertFrom-Json
			foreach ($line in $json | Get-Member) {
				# ensure owner is owned by ESXi host
				if($vsanStatus.NodeUuid -eq $json.$($line.Name).owner) {
					if($json.$($line.Name).isSsd) {
						$totalSsdCapacity += $json.$($line.Name).capacity
						$totalSsdCapacityUsed += $json.$($line.Name).capacityUsed
						$totalSsdCapacityReserved += $json.$($line.Name).capacityReserved
					} else {
						$totalMdCapacity += $json.$($line.Name).capacity
						$totalMdCapacityUsed += $json.$($line.Name).capacityUsed
						$totalMdCapacityReserved += $json.$($line.Name).capacityReserved
					}				
				}
			}
		}
		$totalSsdCapacityReservedPercent = [int]($totalSsdCapacityReserved / $totalSsdCapacity * 100)
		$totalSsdCapacityUsedPercent = [int]($totalSsdCapacityUsed / $totalSsdCapacity * 100)
		$totalMdCapacityReservedPercent = [int]($totalMdCapacityReserved / $totalMdCapacity * 100)
		$totalMdCapacityUsedPercent = [int]($totalMdCapacityUsed / $totalMdCapacity * 100)
		
		$Details = "" |Select VSANCluster, TotalSsdCapacity, TotalSsdCapacityReserved, TotalSsdCapacityUsed,TotalSsdCapacityReservedPercent, TotalSsdCapacityUsedPercent, TotalMdCapacity, TotalMdCapacityReserved, TotalMdCapacityUsed, TotalMdCapacityReservedPercent, TotalMdCapacityUsedPercent
		$Details.VSANCluster = $cluster.Name + "`n"
		$Details.TotalSsdCapacity = [math]::round($totalSsdCapacity /1GB,2).ToString() + " GB"
		$Details.TotalSsdCapacityReserved = [math]::round($totalSsdCapacityReserved /1GB,2).ToString() + " GB"
		$Details.TotalSsdCapacityUsed = [math]::round($totalSsdCapacityUsed /1GB,2).ToString() + " GB"
		$Details.TotalSsdCapacityReservedPercent = $totalSsdCapacityReservedPercent.ToString() + "%"
		$Details.TotalSsdCapacityUsedPercent = $totalSsdCapacityUsedPercent.ToString() + "%`n"
		$Details.TotalMdCapacity = [math]::round($totalMdCapacity /1GB,2).ToString() + " GB"
		$Details.TotalMdCapacityReserved = [math]::round($totalMdCapacityReserved /1GB,2).ToString() + " GB"
		$Details.TotalMdCapacityUsed = [math]::round($totalMdCapacityUsed /1GB,2).ToString() + " GB"
		$Details.TotalMdCapacityReservedPercent = $totalMdCapacityReservedPercent.ToString() + "%"
		$Details.TotalMdCapacityUsedPercent = $totalMdCapacityUsedPercent.ToString() + "%"
		$vsanMaxConfigInfo += $Details
		
		$totalSsdCapacity = 0
		$totalSsdCapacityReserved = 0
		$totalSsdCapacityUsed = 0
		$totalSsdCapacityReservedPercent = 0
		$totalSsdCapacityUsedPercent = 0
		$totalMdCapacity = 0
		$totalMdCapacityReserved = 0
		$totalMdCapacityUsed = 0
		$totalMdCapacityReservedPercent = 0
		$totalMdCapacityUsedPercent = 0
	}
}

$vsanMaxConfigInfo

#Disconnect from vCenter
Disconnect-VIServer $vcenter -Confirm:$false
