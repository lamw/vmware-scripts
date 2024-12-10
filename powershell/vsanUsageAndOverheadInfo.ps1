$vsanCluster = "sfo-m01-cl01"

### DO NOT EDIT BEYOND HERE ###

$vsrs = Get-VsanView VsanSpaceReportSystem-vsan-cluster-space-report-system

# Helper function to convert Bytes into MB, GB & TB
function Convert-Bytes {
    param (
        [Parameter(Mandatory)]
        [double]$Bytes
    )

    if ($Bytes -ge 1TB) {
       "$([math]::Round($Bytes / 1TB, 2)) TB"
    } elseif ($Bytes -ge 1GB) {
        "$([math]::Round($Bytes / 1GB, 2)) GB"
    } elseif ($Bytes -ge 1MB) {
        "$([math]::Round($Bytes / 1MB, 2)) MB" 
    } else {
        "$([math]::Round($Bytes, 2)) Bytes"
    }
}

# Map ObjecType to friendly vSAN UI labels
$vsanObjectTypes = @{
    "fileSystemOverhead" = "File system ovehead"
    "dedupOverhead" = "Deduplication and compression overhead"
    "checksumOverhead" = "Checksum overhead"
    "traceobject" = "Native trace objects"
    "statsdb" = "Performance management objects"
    "vmswap" = "Swap objects"
    "vdisk" = "VMDK"
    "namespace" = "VM home objects (VM namespace)"
}

$vsanUsage = $vsrs.VsanQuerySpaceUsage((Get-Cluster $vsanCluster).ExtensionData.MoRef,$null,$null)
$overheads = $vsanUsage.SpaceDetail.SpaceUsageByObjectType

$results = @()
foreach ($overhead in $overheads) {
    if($overhead.ObjType -ne "minSpaceRequiredForVsanOp") {
        $tmp = [pscustomobject] @{
            Type = $vsanObjectTypes[$overhead.ObjType]
            Overhead = Convert-Bytes -Bytes $overhead.OverheadB
        }
        $results+=$tmp
    }
}
$results | Sort-Object -Property Type | ft