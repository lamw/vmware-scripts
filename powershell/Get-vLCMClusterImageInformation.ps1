<#
    .DESCRIPTION Retrieves vLCM vSphere Lifecycle Management (vLCM) Image details for a vSphere Cluster
    .NOTES  Author: William Lam, Broadcom
    .NOTES  Last Updated: 02/06/2025
    .PARAMETER ClusterName
        Name of a vLCM enabled vSphere Cluster
    .PARAMETER ShowBaseImageDetails
        Output the component details for ESXi base image
    .EXAMPLE
        Get-vLCMClusterImageInformation -ClusterName "ML Cluster"
    .EXAMPLE
        Get-vLCMClusterImageInformation -ClusterName "ML Cluster" -ShowBaseImageDetails
#>
Function Get-vLCMClusterImageInformation {
    param(
        [Parameter(Mandatory=$true)]$ClusterName,
        [Switch]$ShowBaseImageDetails=$false
    )

    Write-host -ForegroundColor Yellow "`nvSphere Lifecycle Management (vLCM) Image for vSphere Cluster: ${clusterName}"

    $clusterMoRef = (Get-Cluster -Name $clusterName).ExtensionData.MoRef.Value

    $clusterSoftware = Invoke-GetClusterSoftware -Cluster $clusterMoRef

    Write-host -ForegroundColor Cyan "`nBase Image: "

    $baseImage = $clusterSoftware.base_image

    $baseImageDetails = Invoke-GetVersionBaseImages -Version $baseImage.version

    $tmp = [PSCustomObject] [ordered] @{
        "Name" = "$(${baseImage}.details.display_name) $(${baseImage}.details.display_version)"
        "Version" = $baseImage.version
        "ReleaseDate" = $baseImage.details.release_date
        "ReleaseNotes" = $baseImageDetails.kb
    }

    $tmp | ft

    if($ShowBaseImageDetails) {
        $baseImageComponentsResults = @()
        Write-host -ForegroundColor Cyan "Base Image Details: "

        $baseImageComponents = $baseImageDetails.components | where {$_.name -ne "ESXi"} | Sort-Object -Property Name
        foreach ($baseImageComponent in $baseImageComponents) {
            $tmp = [PSCustomObject] [ordered] @{
                "Name" = $baseImageComponent.name
                "Version" = $baseImageComponent.version
                "DisplayName" = $baseImageComponent.display_name
                "DisplayVersion" = $baseImageComponent.display_version
            }
            $baseImageComponentsResults+=$tmp
        }
        $baseImageComponentsResults | ft
    }

    Write-Host -ForegroundColor Red "Solutions: "

    $solutionResults = @()
    $softwareSolutions = $clusterSoftware.solutions

    foreach ($solutionId in ($softwareSolutions | Get-Member -MemberType NoteProperty).Name) {
        $solution = ${softwareSolutions}.${solutionId}
        $solutionComponents = $solution.details.components

        foreach ($solutionComponent in $solutionComponents) {
            $tmp = [PSCustomObject] [ordered] @{
                "Name" = $solutionComponents.component
                "Version" = $solution.version
                "Vendor" = $solutionComponents.vendor
                "DisplayName"= $solutionComponents.display_name
                "DisplayVersion" = $solution.details.display_version
                "Id" = $solutionId
            }
            $solutionResults+= $tmp
        }
    }

    $solutionResults | ft

    Write-Host -ForegroundColor Green "FirmwareAddOns: "

    $firmwareResults = @()
    $firmwareAddOns = $clusterSoftware.hardware_support.packages

    if($firmwareAddOns) {
        $firmwareAddOnsHsm = ($firmwareAddOns | Get-Member -MemberType NoteProperty).Name
        $firmwareAddOnsName = ($firmwareAddOns).$firmwareAddOnsHsm.pkg
        $firmwareAddOnsVersion = ($firmwareAddOns.$firmwareAddOnsHsm).version

        $firmwareResults = [PSCustomObject] [ordered] @{
            "HSM Name" = "$firmwareAddOnsHsm"
            "FirmwareAddOn Name" = "$firmwareAddOnsName"
            "Version" = "$firmwareAddOnsVersion"
        }

        $firmwareResults | ft
    }

    Write-Host -ForegroundColor Magenta "Components: "

    $componentResults = @()
    $softwareComponents = $clusterSoftware.components
    foreach ($componetName in ($softwareComponents | Get-Member -MemberType NoteProperty).Name) {
        $component = ${softwareComponents}.${componetName}

        $tmp = [PSCustomObject] [ordered] @{
            "Name" = $componetName
            "Version" = $component.Version
            "Vendor" = $component.details.Vendor
            "DisplayName" = $component.details.display_name
            "DisplayVersion" = $component.details.display_version
        }
        $componentResults+= $tmp
    }

    $componentResults | ft
}