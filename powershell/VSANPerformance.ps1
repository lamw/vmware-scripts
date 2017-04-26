Function Get-VSANPerformanceEntityType {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.virtuallyghetto.com
     Twitter:       @lamw
        ===========================================================================
    .DESCRIPTION
        This function retreives all available vSAN Performance Metric Entity Types
    .EXAMPLE
        Get-VSANPerformanceEntityType
#>
    $vpm = Get-VSANView -Id "VsanPerformanceManager-vsan-performance-manager"
    $entityTypes = $vpm.VsanPerfGetSupportedEntityTypes()

    foreach ($entityType in $entityTypes | Sort-Object -Property Name) {
        $entityType.Name
    }
}

Function Get-VSANPerformanceEntityMetric {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.virtuallyghetto.com
     Twitter:       @lamw
        ===========================================================================
    .DESCRIPTION
        This function retreives all vSAN Performance Metrics for a given Entity Type
    .PARAMETER EntityType
        The name of the vSAN Performance Entity Type you wish to retrieve metrics on
    .EXAMPLE
        Get-VSANPerformanceEntityMetric -EntityType "cache-disk"
#>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("cache-disk","capacity-disk","cluster-domclient","cluster-domcompmgr",
        "disk-group","host-domclient","host-domcompmgr","virtual-disk","virtual-machine",
        "vsan-host-net","vsan-iscsi-host","vsan-iscsi-lun","vsan-iscsi-target","vsan-pnic-net",
        "vsan-vnic-net","vscsi"
        )]
        [String]$EntityType
    )

    $vpm = Get-VSANView -Id "VsanPerformanceManager-vsan-performance-manager"
    $entityTypes = $vpm.VsanPerfGetSupportedEntityTypes()

    $results = @()
    foreach ($et in $entityTypes) {
        if($et.Name -eq $EntityType) {
            $graphs = $et.Graphs
            foreach ($graph in $graphs) {
                foreach ($metric in $graph.Metrics) {
                    $metricObj = [pscustomobject] @{
                        MetricID = $metric.Label
                        Description = $metric.Description
                    }
                    $results+=$metricObj
                }
            }
        }
    }
    $results | Sort-Object -Property MetricID
}

Function Get-VSANPerformanceStat {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.virtuallyghetto.com
     Twitter:       @lamw
        ===========================================================================
    .DESCRIPTION
        This function retreives a particlular vSAN Performance Metric 
        from a vSAN Cluster using vSAN Management APIs 
    .PARAMETER Cluster
        The name of the vSAN Cluster
    .PARAMETER StartTime
        The start time to scope the query (format: "04/23/2017 4:00")
    .PARAMETER EndTime
        The end time to scope the query (format: "04/23/2017 4:10")
    .PARAMETER EntityId
        The vSAN Management API Entity Reference. Please refer to vSAN Mgmt API docs
    .EXAMPLE
        Get-VSANPerformanceStats -Cluster VSAN-Cluster -StartTime "04/23/2017 4:00" -EndTime "04/23/2017 4:05" -EntityId "disk-group:5239bee8-9297-c091-df17-241a4c197f8d"
#>
    param(
        [Parameter(Mandatory=$true)][String]$Cluster,
        [Parameter(Mandatory=$true)][String]$StartTime,
        [Parameter(Mandatory=$true)][String]$EndTime,
        [Parameter(Mandatory=$true)][String]$EntityId
    )
    function Convert-StringToDateTime {
        # Borrowed from https://blogs.technet.microsoft.com/heyscriptingguy/2014/12/19/powertip-convert-string-into-datetime-object/#comment-209544
        param
        (
        [Parameter(Mandatory = $true)]
        [String] $DateTimeStr
        )
        $DateFormatParts = (Get-Culture).DateTimeFormat.ShortDatePattern -split ‘/|-|\.’

        $Month_Index = ($DateFormatParts | Select-String -Pattern ‘M’).LineNumber – 1
        $Day_Index = ($DateFormatParts | Select-String -Pattern ‘d’).LineNumber – 1
        $Year_Index = ($DateFormatParts | Select-String -Pattern ‘y’).LineNumber – 1

        $DateTimeParts = $DateTimeStr -split ‘/|-|\.| ‘
        $DateTimeParts_LastIndex = $DateTimeParts.Count – 1

        $DateTime = [DateTime] $($DateTimeParts[$Month_Index] + ‘/’ + $DateTimeParts[$Day_Index] + ‘/’ + $DateTimeParts[$Year_Index] + ‘ ‘ + $DateTimeParts[3..$DateTimeParts_LastIndex] -join ‘ ‘)

        return $DateTime
    }

    $cluster_view = (Get-Cluster -Name $cluster).ExtensionData.MoRef

    $vpm = Get-VSANView -Id "VsanPerformanceManager-vsan-performance-manager"

    $start = Convert-StringToDateTime $StartTime
    $end = Convert-StringToDateTime $EndTime

    $spec = New-Object VMware.Vsan.Views.VsanPerfQuerySpec
    $spec.EntityRefId = $EntityId
    $spec.StartTime = $startTime
    $spec.EndTime = $endTime
    $vpm.VsanPerfQueryPerf(@($spec),$cluster_view)
}