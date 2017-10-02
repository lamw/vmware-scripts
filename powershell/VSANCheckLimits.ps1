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
        the exact same information provided by the RVC command "vsan.check_limits"
        Please see http://www.virtuallyghetto.com/2017/06/how-to-convert-vsan-rvc-commands-into-powercli-andor-other-vsphere-sdks.html for more details
    .PARAMETER Cluster
        The name of a vSAN Cluster
    .EXAMPLE
        Get-VsanLimits -Cluster VSAN-Cluster
#>
Function Get-VsanLimits {
    param(
        [Parameter(Mandatory=$true)][String]$Cluster
    )

    $vmhosts = (Get-Cluster -Name $Cluster | Get-VMHost | Sort-Object -Property Name)

    $limitsResults = @()
    foreach($vmhost in $vmhosts) {
        $connectionState = $vmhost.ExtensionData.Runtime.runtime.connectionState
        $vsanEnabled = (Get-View $vmhost.ExtensionData.ConfigManager.vsanSystem).config.enabled

        if($connectionState -ne "Connected" -and $vsanEnabled -ne $true) {
            break
        }

        $vsanInternalSystem = Get-View $vmhost.ExtensionData.ConfigManager.vsanInternalSystem

        # Fetch RDT Information
        $resultsForRdtLsomDom = $vsanInternalSystem.QueryVsanStatistics(@('rdtglobal','lsom-node','lsom','dom','dom-objects-counts'))
        $jsonFroRdtLsomDom = $resultsForRdtLsomDom | ConvertFrom-Json

        # Process RDT Data Start #
        $rdtAssocs = $jsonFroRdtLsomDom.'rdt.globalinfo'.assocCount.ToString() + "/" + $jsonFroRdtLsomDom.'rdt.globalinfo'.maxAssocCount.ToString()
        $rdtSockets = $jsonFroRdtLsomDom.'rdt.globalinfo'.socketCount.ToString() + "/" + $jsonFroRdtLsomDom.'rdt.globalinfo'.maxSocketCount.ToString()
        $rdtClients = 0
        foreach($line in $jsonFroRdtLsomDom.'dom.clients' | Get-Member) {
            # crappy way to iterate through keys ...
            if($($line.Name) -ne "Equals" -and $($line.Name) -ne "GetHashCode" -and $($line.Name) -ne "GetType" -and $($line.Name) -ne "ToString") {
                $rdtClients++
            }
        }
        $rdtOwners = 0
        foreach($line in $jsonFroRdtLsomDom.'dom.owners.count' | Get-Member) {
            # crappy way to iterate through keys ...
            if($($line.Name) -ne "Equals" -and $($line.Name) -ne "GetHashCode" -and $($line.Name) -ne "GetType" -and $($line.Name) -ne "ToString") {
                $rdtOwners++
            }
        }
        # Process RDT Data End #

        # Fetch Component information
        $resultsForComponents = $vsanInternalSystem.QueryPhysicalVsanDisks(@('lsom_objects_count','uuid','isSsd','capacity','capacityUsed'))
        $jsonForComponents = $resultsForComponents | ConvertFrom-Json

        # Process Component Data Start #
        $vsanUUIDs = @{}
        $vsanDiskMgmtSystem = Get-VsanView -Id VimClusterVsanVcDiskManagementSystem-vsan-disk-management-system
        $diskGroups = $vsanDiskMgmtSystem.QueryDiskMappings($vmhost.ExtensionData.Moref)
        foreach($diskGroup in $diskGroups) {
            $mappings = $diskGroup.mapping
            foreach($mapping in $mappings ) {
                $ssds = $mapping.ssd
                $nonSsds = $mapping.nonSsd

                foreach($ssd in $ssds ) {
                    $vsanUUIDs.add($ssd.vsanDiskInfo.vsanUuid,$ssd)
                }

                foreach($nonSsd in $nonSsds ) {
                    $vsanUUIDs.add($nonSsd.vsanDiskInfo.vsanUuid,$nonSsd)
                }
            }
        }
        $maxComponents = $jsonFroRdtLsomDom.'lsom.node'.numMaxComponents

        $diskString = ""
        $hostComponents = 0
        foreach($line in $jsonForComponents | Get-Member) {
            # crappy way to iterate through keys ...
            if($($line.Name) -ne "Equals" -and $($line.Name) -ne "GetHashCode" -and $($line.Name) -ne "GetType" -and $($line.Name) -ne "ToString") {
                if($vsanUUIDs.ContainsKey($line.Name)) {
                    $numComponents = ($jsonFroRdtLsomDom.'lsom.disks'.$($line.Name).info.numComp).toString()
                    $maxCoponents = ($jsonFroRdtLsomDom.'lsom.disks'.$($line.Name).info.maxComp).toString()
                    $hostComponents += $jsonForComponents.$($line.Name).lsom_objects_count
                    $usage = ($jsonFroRdtLsomDom.'lsom.disks'.$($line.Name).info.capacityUsed * 100) / $jsonFroRdtLsomDom.'lsom.disks'.$($line.Name).info.capacity
                    $usage = [math]::ceiling($usage)

                    $diskString+=$vsanUUIDs.$($line.Name).CanonicalName + ": " + $usage + "% Components: " + $numComponents + "/" + $maxCoponents + "`n"
                }
            }
        }
        # Process Component Data End #

        # Store output into an object
        $hostLimitsResult = [pscustomobject] @{
            Host = $vmhost.Name
            RDT = "Assocs: " + $rdtAssocs + "`nSockets: " + $rdtSockets + "`nClients: " + $rdtClients + "`nOwners: " + $rdtOwners
            Disks = "Components: " + $hostComponents + "/" + $maxComponents + "`n" + $diskString
        }
        $limitsResults+=$hostLimitsResult
    }
    # Display output
    $limitsResults | Format-Table -Wrap
}