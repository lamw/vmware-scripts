# ============================================================================
# VCF 9.1.1 - Add a SINGLE ESXi Host cluster to an EXISTING Workload Domain
#
# Talks to SDDC Manager directly over its REST API.
#
# This does NOT create a new Workload Domain - it adds an additional cluster
# to one that already exists, using its already-registered vCenter and NSX
# Manager. For creating the Workload Domain itself, see the sibling script
# vcf-single-host-shared-nsx-wld-deployment.ps1.
#
# PRE-REQUISITES (manual, one-time, requires SSH/root access to SDDC Manager -
# not automated by this script):
#
#   Single-host clusters are blocked by default. Enable the feature flag and
#   minimum cluster size override, then restart services:
#
#     echo "feature.vcf.vgl-29121.single.host.domain = true" >> /home/vcf/feature.properties
#     echo "bringup.mgmt.cluster.minimum.size = 1" >> /etc/vmware/vcf/domainmanager/application-prod.properties
#     echo 'y' | /opt/vmware/vcf/operationsmanager/scripts/cli/sddcmanager_restart_services.sh
#
#   Ref: https://williamlam.com/2026/05/vcf-9-1-comprehensive-vcf-installer-sddc-manager-configuration-workarounds-for-lab-deployments.html
#
# Author (script pattern based on): William Lam - https://williamlam.com
# ============================================================================

param (
    [Parameter(Mandatory=$true)][string]$EnvConfigFile,
    [switch]$ValidateOnly
)

if ($EnvConfigFile -and (Test-Path $EnvConfigFile)) {
    . $EnvConfigFile
} else {
    Write-Host -ForegroundColor Red "`nNo valid deployment configuration file was provided or file was not found.`n"
    exit
}

#### DO NOT EDIT BEYOND HERE ####

$verboseLogFile = "vcf-single-host-cluster-deployment.log"
$VCFClusterDeploymentJSONFile = "${VCFClusterName}.json"
$StartTime = Get-Date

Function My-Logger {
    param(
        [Parameter(Mandatory=$true)][String]$message,
        [Parameter(Mandatory=$false)][String]$color="green"
    )
    $timeStamp = Get-Date -Format "MM-dd-yyyy_hh:mm:ss"
    Write-Host -NoNewline -ForegroundColor White "[$timeStamp]"
    Write-Host -ForegroundColor $color " $message"
    "[$timeStamp] $message" | Out-File -Append -LiteralPath $verboseLogFile
}

# Thin wrapper around Invoke-RestMethod for calls to SDDC Manager.
# Lab/home-lab SDDC Manager instances typically use a self-signed certificate,
# so certificate validation is skipped on PowerShell Core (macOS/Linux).
# Windows PowerShell does not support -SkipCertificateCheck, hence the branch.
Function Invoke-SddcManagerApi {
    param(
        [Parameter(Mandatory=$true)][String]$Method,
        [Parameter(Mandatory=$true)][String]$Path,
        [Parameter(Mandatory=$false)][String]$Body,
        [Parameter(Mandatory=$false)][String]$Token
    )
    $uri = "https://${sddcManagerFQDN}${Path}"
    $headers = @{ "Accept" = "application/json" }
    if ($Token) { $headers["Authorization"] = "Bearer $Token" }

    $restArgs = @{
        Method  = $Method
        Uri     = $uri
        Headers = $headers
    }
    if ($Body) {
        $restArgs["ContentType"] = "application/json"
        $restArgs["Body"] = $Body
    }
    if ($PSEdition -eq 'Core') {
        $restArgs["SkipCertificateCheck"] = $true
    }

    Invoke-RestMethod @restArgs
}

Write-Host -ForegroundColor Magenta "`nPlease confirm the following configuration will be deployed:`n"
Write-Host -ForegroundColor Yellow "---- Target Workload Domain ----"
Write-Host -NoNewline -ForegroundColor Green "Name: "; Write-Host -ForegroundColor White $VCFWorkloadDomainName
Write-Host -ForegroundColor Yellow "`n---- New Cluster ----"
Write-Host -NoNewline -ForegroundColor Green "Name: "; Write-Host -ForegroundColor White $VCFClusterName
Write-Host -NoNewline -ForegroundColor Green "ESXi Host: "; Write-Host -ForegroundColor White $ESXiHostFQDN

Write-Host -ForegroundColor Magenta "`nWould you like to proceed with this deployment?`n"
$answer = Read-Host -Prompt "Do you accept (Y or N)"
if ($answer -notmatch "^[Yy]$") { exit }
Clear-Host

# ----------------------------------------------------------------------------
# Authenticate to SDDC Manager and get an API access token
# ----------------------------------------------------------------------------
My-Logger "Logging into SDDC Manager $sddcManagerFQDN ..."
$tokenBody = @{ "username" = $sddcManagerUsername; "password" = $sddcManagerPassword } | ConvertTo-Json
$tokenResponse = Invoke-SddcManagerApi -Method POST -Path "/v1/tokens" -Body $tokenBody
$accessToken = $tokenResponse.accessToken
if (-not $accessToken) {
    My-Logger "Authentication failed - no access token returned" "red"
    exit
}

# ----------------------------------------------------------------------------
# Find the target Workload Domain. Its ID (not its name) is what the cluster
# creation spec actually needs to say where the new cluster goes.
# ----------------------------------------------------------------------------
My-Logger "Looking up Workload Domain '$VCFWorkloadDomainName' ..."
$domainsResponse = Invoke-SddcManagerApi -Method GET -Path "/v1/domains" -Token $accessToken
$targetDomain = $domainsResponse.elements | Where-Object { $_.name -eq $VCFWorkloadDomainName }
if (-not $targetDomain) {
    My-Logger "Unable to find Workload Domain named '$VCFWorkloadDomainName'" "red"
    exit
}
My-Logger "Found Workload Domain '$VCFWorkloadDomainName' with ID $($targetDomain.id)"

# ----------------------------------------------------------------------------
# Find the ESXi host in SDDC Manager's inventory.
#
# The host must already be commissioned (this script does not commission
# hosts) and sitting unused, which is what UNASSIGNED_USEABLE means.
# ----------------------------------------------------------------------------
My-Logger "Looking up already-commissioned host $ESXiHostFQDN ..."
$hostsResponse = Invoke-SddcManagerApi -Method GET -Path "/v1/hosts?status=UNASSIGNED_USEABLE" -Token $accessToken
$commissionedHost = $hostsResponse.elements | Where-Object { $_.fqdn -eq $ESXiHostFQDN }
if (-not $commissionedHost) {
    My-Logger "Unable to find $ESXiHostFQDN as an UNASSIGNED_USEABLE host in SDDC Manager inventory" "red"
    My-Logger "Confirm it has been commissioned and is not already assigned to a domain/cluster" "red"
    exit
}
My-Logger "Found host $ESXiHostFQDN with ID $($commissionedHost.id)"

# The storage type a host was commissioned with determines which datastore
# spec shape is valid later on. Trust what SDDC Manager already recorded for
# this host over whatever the config file assumes, since a mismatch here is
# rejected at validation time anyway.
$detectedStorageType = $commissionedHost.datastoreType
if (-not $detectedStorageType) { $detectedStorageType = $commissionedHost.compatibleStorageType }
My-Logger "Host commissioned storage type (from inventory): datastoreType='$($commissionedHost.datastoreType)' compatibleStorageType='$($commissionedHost.compatibleStorageType)'"
if ($detectedStorageType -and $detectedStorageType -ne $ESXiHostStorageType) {
    My-Logger "NOTE: inventory reports '$detectedStorageType' but config file says '$ESXiHostStorageType' - using inventory value" "yellow"
    $ESXiHostStorageType = $detectedStorageType
}

# ----------------------------------------------------------------------------
# Find the vLCM cluster image to use for lifecycle management.
#
# VCF 9.1 requires vSphere Lifecycle Manager Images (not the older baseline
# model) for cluster lifecycle management, so the cluster spec needs the
# image's ID, not just its name.
# ----------------------------------------------------------------------------
My-Logger "Looking up vLCM Image '$VLCMImageName' ..."
$personalitiesResponse = Invoke-SddcManagerApi -Method GET -Path "/v1/personalities" -Token $accessToken
$clusterImageId = ($personalitiesResponse.elements | Where-Object { $_.personalityName -eq $VLCMImageName }).personalityId
if (-not $clusterImageId) {
    My-Logger "Unable to find vLCM Image named '$VLCMImageName' under Lifecycle Management -> Image Management" "red"
    exit
}
My-Logger "Using vLCM Image ID $clusterImageId"

# ----------------------------------------------------------------------------
# Build the Cluster creation spec
# ----------------------------------------------------------------------------
My-Logger "Generating Cluster deployment file $VCFClusterDeploymentJSONFile ..."

# This lab host only has a single usable physical NIC (vmnic1).
$hostSpecs = @(
    [ordered]@{
        "id"         = $commissionedHost.id
        "licenseKey" = $ESXILicense
        "hostNetworkSpec" = @{
            "vmNics" = @(
                @{ "id" = "vmnic1"; "vdsName" = "$VCFClusterName-vds01" }
            )
        }
    }
)

# A single-host cluster is its own single point of failure, so vSAN can't be
# asked to tolerate any host failures (failuresToTolerate must be 0 - vSAN ESA
# has no equivalent setting since it doesn't use the older FTT model).
if ($ESXiHostStorageType -eq "VSAN_ESA") {
    $datastoreSpec = @{
        "vsanDatastoreSpec" = [ordered]@{
            "licenseKey"    = $VSANLicense
            "datastoreName" = "$VCFClusterName-vsan01"
            # skipHclAutoDiskClaim: this lab's disks aren't on the vSAN HCL,
            # so let vSAN claim them anyway instead of blocking on that check.
            "esaConfig"     = @{ "enabled" = $true; "skipHclAutoDiskClaim" = $true }
        }
    }
} elseif ($ESXiHostStorageType -eq "VSAN") {
    $datastoreSpec = @{
        "vsanDatastoreSpec" = [ordered]@{
            "failuresToTolerate" = "0"
            "licenseKey"         = $VSANLicense
            "datastoreName"      = "$VCFClusterName-vsan01"
        }
    }
} else {
    My-Logger "Storage type '$ESXiHostStorageType' is not VSAN/VSAN_ESA - this script only builds vsanDatastoreSpec today." "red"
    My-Logger "Raw host object storage-related fields: datastoreType='$($commissionedHost.datastoreType)' compatibleStorageType='$($commissionedHost.compatibleStorageType)' hybrid='$($commissionedHost.hybrid)'" "red"
    exit
}

# The NSX overlay/transport config for this cluster (VLAN + TEP IP pool).
# The domain's NSX Manager already exists - this is just specific to this
# new cluster's hosts, not to the NSX Manager appliance itself.
$nsxTClusterSpec = [ordered]@{
    "geneveVlanId"     = $GeneveVlanId
    "ipAddressPoolSpec" = @{
        "name"    = $NSXIpPoolName
        "subnets" = @(
            [ordered]@{
                "cidr"    = $NSXIpPoolCidr
                "gateway" = $NSXIpPoolGateway
                "ipAddressPoolRanges" = @(
                    [ordered]@{ "start" = $NSXIpPoolRangeStart; "end" = $NSXIpPoolRangeEnd }
                )
            }
        )
    }
}

$payload = [ordered]@{
    "domainId" = $targetDomain.id
    "computeSpec" = [ordered]@{
        "clusterSpecs" = @(
            [ordered]@{
                "name"           = $VCFClusterName
                "datacenterName" = $VCFDatacenterName
                "clusterImageId" = $clusterImageId
                "hostSpecs"      = $hostSpecs
                "datastoreSpec"  = $datastoreSpec
                "networkSpec"    = @{
                    "vdsSpecs" = @(
                        [ordered]@{
                            "name" = "$VCFClusterName-vds01"
                            "portGroupSpecs" = @(
                                @{ "name" = "$VCFClusterName-vds01-management"; "transportType" = "MANAGEMENT" }
                                @{ "name" = "$VCFClusterName-vds01-vmotion"; "transportType" = "VMOTION" }
                                @{ "name" = "$VCFClusterName-vds01-vsan"; "transportType" = "VSAN" }
                            )
                        }
                    )
                    "nsxClusterSpec" = [ordered]@{
                        "nsxTClusterSpec" = $nsxTClusterSpec
                    }
                }
            }
        )
    }
}

$LicenseLater = $true
if ($LicenseLater) {
    $evaluationMode = ($ESXILicense -eq "" -and $VSANLicense -eq "")
    $payload.add("deployWithoutLicenseKeys", $evaluationMode)
}

$payload | ConvertTo-Json -Depth 12 | Out-File -Force $VCFClusterDeploymentJSONFile
My-Logger "Wrote $VCFClusterDeploymentJSONFile"

# ----------------------------------------------------------------------------
# Validate the spec before submitting it for real. SDDC Manager runs this
# same check internally on creation anyway, but validating first lets us stop
# and show the actual errors instead of finding out after submission.
# ----------------------------------------------------------------------------
My-Logger "Validating Cluster spec against SDDC Manager ..."
$specBody = Get-Content -Raw $VCFClusterDeploymentJSONFile
$validation = Invoke-SddcManagerApi -Method POST -Path "/v1/clusters/validations" -Body $specBody -Token $accessToken

if (-not ($validation.executionStatus -eq "COMPLETED" -and $validation.resultStatus -eq "SUCCEEDED")) {
    My-Logger "Validation failed, see details below" "red"
    $validation.validationChecks | Where-Object { $_.resultStatus -eq "FAILED" } | ConvertTo-Json -Depth 10 | Write-Host
    exit
}
My-Logger "Validation succeeded."

if ($ValidateOnly) {
    My-Logger "ValidateOnly switch specified, stopping before submission."
    exit
}

# ----------------------------------------------------------------------------
# Submit the Cluster for creation
# ----------------------------------------------------------------------------
My-Logger "Submitting Cluster deployment ..."
$clusterDeployment = Invoke-SddcManagerApi -Method POST -Path "/v1/clusters" -Body $specBody -Token $accessToken
My-Logger "Deployment submitted, task ID: $($clusterDeployment.id)"
My-Logger "Open a browser to https://$sddcManagerFQDN to monitor deployment progress"

$EndTime = Get-Date
$duration = [math]::Round((New-TimeSpan -Start $StartTime -End $EndTime).TotalMinutes, 2)
My-Logger "Done. Took $duration minutes to look up host and submit Cluster deployment."
