<#
.SYNOPSIS
Generates the required VCF Download Tool (VCFDT) binary download commands for latest VCF 9.0.2/9.1.0 release including latest Express Patches

.EXAMPLE
./Get-VCFLatestComponents.ps1 -PVC /Users/lamw/productVersionCatalog.json -DepotStore /Volumes/Storage/Software/VCF-LATEST -CredentialType ActivationCode -CredentialFile /Users/lamw/vcf_activation_code.txt -BaseVersion 9.1.0 -Type INSTALL

.EXAMPLE
./Get-VCFLatestComponents.ps1 -PVC /Users/lamw/productVersionCatalog.json -DepotStore /Volumes/Storage/Software/VCF-LATEST -CredentialType ActivationCode -CredentialFile /Users/lamw/vcf_activation_code.txt -BaseVersion 9.1.0 -Type UPGRADE

.EXAMPLE
./Get-VCFLatestComponents.ps1 -PVC /Users/lamw/productVersionCatalog.json -DepotStore /Volumes/Storage/Software/VCF-LATEST -CredentialType ActivationCode -CredentialFile /Users/lamw/vcf_activation_code.txt -BaseVersion 9.0.2 -Type INSTALL

.EXAMPLE
./Get-VCFLatestComponents.ps1 -PVC /Users/lamw/productVersionCatalog.json -DepotStore /Volumes/Storage/Software/VCF-LATEST -CredentialType ActivationCode -CredentialFile /Users/lamw/vcf_activation_code.txt -BaseVersion 9.0.2 -Type UPGRADE
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$PVC,

    [Parameter(Mandatory)]
    [ValidateSet('9.0.2', '9.1.0')]
    [string]$BaseVersion,

    [ValidateSet('INSTALL', 'UPGRADE')]
    [string]$Type = 'INSTALL',

    [Alias('depot-store')]
    [string]$DepotStore,

    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$CredentialFile,

    [ValidateSet('ActivationCode', 'DownloadToken')]
    [string]$CredentialType = 'ActivationCode',

    [string]$VcfDownloadTool = 'vcf-download-tool',

    [string]$CommandFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Fixed component allowlists for each supported VCF base version.
$componentsByBaseVersion = @{
    '9.1.0' = @(
    'VRA',
    'VSP',
    'SDDC_MANAGER_VCF',
    'VCENTER',
    'NSX_T_MANAGER',
    'VROPS',
    'VCF_OPS_CLOUD_PROXY',
    'DEPOT_SERVICE',
    'TELEMETRY_ACCEPTOR',
    'VCF_FLEET_LCM',
    'VCF_SDDC_LCM',
    'VCF_LICENSE_SERVER',
    'VCF_SERVICE_VCD_MIGRATION_BACKEND',
    'VIDB',
    'VCF_SALT',
    'VCF_SALT_RAAS',
    'VRLI'
    )
    '9.0.2' = @(
    'VCENTER',
    'NSX_T_MANAGER',
    'SDDC_MANAGER_VCF',
    'VRSLCM',
    'VROPS',
    'VCF_OPS_CLOUD_PROXY',
    'VRA'
    )
}

function Get-VersionSortKey {
    param([Parameter(Mandatory)][string]$Version)

    $segments = $Version -split '\.'
    if ($segments | Where-Object { $_ -notmatch '^\d+$' }) {
        throw "Catalog contains a non-numeric product version: '$Version'."
    }

    # Lexical sorting is safe after every numeric segment is zero padded.
    return (($segments | ForEach-Object { ([long]$_).ToString('D12') }) -join '.')
}

function Quote-CommandArgument {
    param([Parameter(Mandatory)][string]$Value)

    if ($Value -notmatch '[\s"'']') { return $Value }
    if ($Value.Contains("'")) {
        throw "Command arguments containing a single quote are not supported: $Value"
    }
    return "'$Value'"
}

function Format-ByteSize {
    param([Parameter(Mandatory)][long]$Bytes)

    if ($Bytes -ge 1GB) { return ('{0:N2} GiB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N2} MiB' -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ('{0:N2} KiB' -f ($Bytes / 1KB)) }
    return "$Bytes B"
}

try {
    $catalog = Get-Content -LiteralPath $PVC -Raw | ConvertFrom-Json
}
catch {
    throw "Unable to parse catalog '$PVC': $($_.Exception.Message)"
}

if ($null -eq $catalog.patches) {
    throw "Catalog '$PVC' does not contain a 'patches' object."
}

$requestedComponents = @($componentsByBaseVersion[$BaseVersion])
if ($BaseVersion -eq '9.1.0' -and $Type -eq 'UPGRADE') {
    # These upgrade payloads are included in the VROPS bundle for VCF 9.1.
    $requestedComponents = @(
        $requestedComponents | Where-Object {
            $_ -notin @('VCF_OPS_CLOUD_PROXY', 'VCF_LICENSE_SERVER')
        }
    )
}
Write-Verbose "Evaluating $($requestedComponents.Count) component(s)."

$results = foreach ($componentName in $requestedComponents) {
    $property = $catalog.patches.PSObject.Properties[$componentName]
    if ($null -eq $property) {
        Write-Warning "Component '$componentName' is not present in the catalog."
        continue
    }

    # Compatibility is a hard upper and lower boundary: never cross release trains.
    $releaseTrains = @($BaseVersion)

    $candidates = @()
    foreach ($releaseTrain in $releaseTrains) {
        $trainCandidates = @(
            foreach ($release in @($property.Value)) {
                if ($release.productVersion -notlike "$releaseTrain.*") { continue }

                foreach ($bundle in @($release.artifacts.bundles)) {
                    $catalogBundleType = if ($Type -eq 'INSTALL') { 'INSTALL' } else { 'PATCH' }
                    if ($bundle.type -ne $catalogBundleType) { continue }

                    [pscustomobject]@{
                        ProductVersion = [string]$release.productVersion
                        SortKey        = Get-VersionSortKey -Version $release.productVersion
                        ReleaseDate    = [datetime]$release.releaseDate
                        Bundle         = $bundle
                    }
                }
            }
        )

        if ($trainCandidates.Count -gt 0) {
            $candidates = $trainCandidates
            break
        }
    }

    $latest = $candidates | Sort-Object SortKey, ReleaseDate -Descending | Select-Object -First 1
    if ($null -eq $latest) {
        Write-Warning "No compatible $Type bundle for '$componentName' was found in the searched release trains: $($releaseTrains -join ', ')."
        continue
    }

    $versionSegments = $latest.ProductVersion -split '\.'
    $componentVersion = ($versionSegments[0..($versionSegments.Count - 2)] -join '.')
    $componentBuild = $versionSegments[-1]
    $binaryNames = @($latest.Bundle.binaries | ForEach-Object { $_.fileName })
    $bundleSizeBytes = [long](($latest.Bundle.binaries | Measure-Object -Property size -Sum).Sum)

    $arguments = @(
        'binaries',
        'download',
        '--sku=VCF',
        "--type=$Type",
        "--vcf-version=$BaseVersion"
    )
    if ($DepotStore) {
        $arguments += "--depot-store=$(Quote-CommandArgument $DepotStore)"
    }
    if ($CredentialFile) {
        $credentialOption = if ($CredentialType -eq 'ActivationCode') {
            '--depot-download-activation-code-file'
        }
        else {
            '--depot-download-token-file'
        }
        $arguments += "$credentialOption=$(Quote-CommandArgument $CredentialFile)"
    }
    $arguments += "--component=$componentName"
    $arguments += "--component-version=$componentVersion"

    [pscustomobject]@{
        Component      = $componentName
        Version        = $componentVersion
        Build          = $componentBuild
        ReleaseDate    = $latest.ReleaseDate.ToString('yyyy-MM-dd')
        Size           = Format-ByteSize -Bytes $bundleSizeBytes
        ProductVersion = $latest.ProductVersion
        Binaries       = $binaryNames -join ', '
        Command        = "$(Quote-CommandArgument $VcfDownloadTool) $($arguments -join ' ')"
    }
}

$results = @($results | Sort-Object Component)
if ($results.Count -eq 0) {
    throw "No matching $Type components were found for base version $BaseVersion."
}

$results | Format-Table Component, Version, Build, ReleaseDate, Size -AutoSize
Write-Host "`nGenerated vcf-download-tool commands:`n"
$results.Command | ForEach-Object { Write-Output $_ }

if ($CommandFile) {
    $results.Command | Set-Content -LiteralPath $CommandFile -Encoding utf8
    Write-Host "`nCommands written to: $CommandFile"
}
