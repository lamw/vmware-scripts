<#
    .SYNOPSIS Checks ESXi IO/Device against Broadcom Compatibility Guide (https://compatibilityguide.broadcom.com/)
    .NOTES  Author:  William Lam
    .NOTES  Site:    www.williamlam.com
    .PARAMETER VID
        VendorID of IO/Device from queryHostPCIInfo.ps1
    .PARAMETER DID
        DeviceID of IO/Device from queryHostPCIInfo.ps1
    .PARAMETER SVID
        SubSystemVendorID of IO/Device from queryHostPCIInfo.ps1
    .PARAMETER ShowNumberOfSupportedReleases
        Show the number of supported ESXi releases
    .EXAMPLE
        Check-BroadcomCompatIoDevice -VID "14e4" -DID "1751" -SVID "14e4"
    .EXAMPLE
        Check-BroadcomCompatIoDevice -VID "14e4" -DID "1751" -SVID "14e4" -ShowNumberOfSupportedReleases 2
#>
Function Check-BroadcomCompatIoDevice {
    param(
        [Parameter(Mandatory=$true)][string]$VID,
        [Parameter(Mandatory=$true)][string]$DID,
        [Parameter(Mandatory=$true)][string]$SVID,
        [Parameter(Mandatory=$false)][string]$ShowNumberOfSupportedReleases=4
    )


    $spec = [ordered]@{
        "programId" = "io"
        "filters" = @(
            @{
                "displayKey" = "vid"
                "filterValues" = @($VID)
            }
            @{
                "displayKey" = "did"
                "filterValues" = @($DID)
            }
            @{
                "displayKey" = "svid"
                "filterValues" = @($SVID)
            }
        )
        "keyword" = @()
        "date" = @{
            "startDate" = $null
            "endDate" = $null
        }
    }

    $body = $spec | ConvertTo-Json -Depth 4

    $requests = Invoke-WebRequest -UseBasicParsing -Uri "https://compatibilityguide.broadcom.com/compguide/programs/viewResults?limit=20&page=1&sortBy=&sortType=ASC" -Method "POST" -ContentType "application/json" -Body $body
    $results = $requests.Content | ConvertFrom-Json

    $hclResults = @()
    if($results.data.count -gt 0) {
        foreach($item in $results.data.fieldValues) {
            $tmp = [pscustomobject] [ordered]@{
                Brand = $item.brandName
                Model = $item.model.name
                DeviceType = $item.deviceType
                SupportedReleases = ($item.supportedReleases.name | select -First $ShowNumberOfSupportedReleases) -join ","
            }
            $hclResults+=$tmp
        }
    }

    $hclResults
}

<#
    .SYNOPSIS Checks ESXi SSD device against Broadcom Compatibility Guide (https://compatibilityguide.broadcom.com/)
    .NOTES  Author:  William Lam
    .NOTES  Site:    www.williamlam.com
    .PARAMETER VID
        VendorID of IO/Device from queryHostPCIInfo.ps1
    .PARAMETER DID
        DeviceID of IO/Device from queryHostPCIInfo.ps1
    .PARAMETER SVID
        SubSystemVendorID of IO/Device from queryHostPCIInfo.ps1
    .PARAMETER ShowNumberOfSupportedReleases
        Show the number of supported ESXi releases
    .PARAMETER ShowHybridCacheTier
        Show only vSAN Hybrid Cache Tier supported devices
    .PARAMETER ShowAFCacheTier
        Show only vSAN All-Flash Cache Tier supported devices
    .PARAMETER ShowAFCapacityTier
        Show only vSAN All-Flash Capacity Tier supported devices
    .PARAMETER ShowESATier
        Show only vSAN ESA supported devices
    .EXAMPLE
        Check-BroadcomCompatVsanSsdDevice -VID "8086" -DID "0b60" -SVID "1028"
    .EXAMPLE
        Check-BroadcomCompatVsanSsdDevice -VID "8086" -DID "0b60" -SVID "1028" -ShowNumberOfSupportedReleases 2
    .EXAMPLE
        Check-BroadcomCompatVsanSsdDevice -VID "8086" -DID "0b60" -SVID "1028" -ShowNumberOfSupportedReleases 2 -ShowESATier
    .EXAMPLE
        Check-BroadcomCompatVsanSsdDevice -VID "8086" -DID "0b60" -SVID "1028" -ShowNumberOfSupportedReleases 2 -ShowAFCacheTier -ShowESATier
#>
Function Check-BroadcomCompatVsanSsdDevice {
    param(
        [Parameter(Mandatory=$true)][string]$VID,
        [Parameter(Mandatory=$true)][string]$DID,
        [Parameter(Mandatory=$true)][string]$SVID,
        [Switch]$ShowHybridCacheTier=$false,
        [Switch]$ShowAFCacheTier=$false,
        [Switch]$ShowAFCapacityTier=$false,
        [Switch]$ShowESATier=$false,
        [Parameter(Mandatory=$false)][string]$ShowNumberOfSupportedReleases=4
    )

    $spec = [ordered]@{
        "programId" = "ssd"
        "filters" = @(
            @{
                "displayKey" = "vid"
                "filterValues" = @($VID)
            }
            @{
                "displayKey" = "did"
                "filterValues" = @($DID)
            }
            @{
                "displayKey" = "svid"
                "filterValues" = @($SVID)
            }
        )
        "keyword" = @()
        "date" = @{
            "startDate" = $null
            "endDate" = $null
        }
    }

    $tierFilterValues = @()
    if($ShowHybridCacheTier) {
        $tierFilterValues+="vSAN Hybrid Caching Tier"
    }

    if($ShowAFCacheTier) {
        $tierFilterValues+="vSAN All Flash Caching Tier"
    }

    if($ShowAFCapacityTier) {
        $tierFilterValues+="vSAN All Flash Capacity Tier"
    }

    if($ShowESATier) {
        $tierFilterValues+="vSAN ESA Storage Tier"
    }

    if($tierFilterValues -ne $null) {
        $spec.filters+= @{
            "displayKey" = "tier"
            "filterValues" =$tierFilterValues
        }
    }

    $body = $spec | ConvertTo-Json -Depth 4

    $requests = Invoke-WebRequest -UseBasicParsing -Uri "https://compatibilityguide.broadcom.com/compguide/programs/viewResults?limit=20&page=1&sortBy=&sortType=ASC" -Method "POST" -ContentType "application/json" -Body $body
    $results = $requests.Content | ConvertFrom-Json

    $hclResults = @()
    if($results.data.count -gt 0) {
        foreach($item in $results.data.fieldValues) {
            $tmp = [pscustomobject] [ordered]@{
                PartnerName = $item.partnerName
                Model = $item.model.name
                Tier = $item.tier
                SupportedReleases = $item.supportedReleases | select -First $ShowNumberOfSupportedReleases
            }
            $hclResults+=$tmp
        }
    }

    $hclResults
}