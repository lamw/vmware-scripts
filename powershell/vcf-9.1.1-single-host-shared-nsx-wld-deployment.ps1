# ============================================================================
# VCF 9.1.1 - Deploy a Workload Domain with a SINGLE ESXi Host that shares
#             an EXISTING NSX Manager instance
#
# Talks to SDDC Manager directly over its REST API.
#
# PRE-REQUISITES (manual, one-time, requires SSH/root access to SDDC Manager -
# not automated by this script):
#
#   1) Single-host Workload Domains are blocked by default. Enable the
#      feature flag and minimum cluster size override, then restart services:
#
#         echo "feature.vcf.vgl-29121.single.host.domain = true" >> /home/vcf/feature.properties
#         echo "bringup.mgmt.cluster.minimum.size = 1" >> /etc/vmware/vcf/domainmanager/application-prod.properties
#         echo 'y' | /opt/vmware/vcf/operationsmanager/scripts/cli/sddcmanager_restart_services.sh
#
#      Ref: https://williamlam.com/2026/05/vcf-9-1-comprehensive-vcf-installer-sddc-manager-configuration-workarounds-for-lab-deployments.html
#
#   2) The NSX Manager being shared must already exist and be registered in
#      SDDC Manager (e.g. it backs the Management Domain or another Workload
#      Domain already). This script never deploys a new NSX Manager - giving
#      SDDC Manager that instance's real details is what makes it join the
#      existing cluster instead. Ref: KB 401167 (Join Existing NSX Manager).
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

$verboseLogFile = "vcf-single-host-shared-nsx-wld-deployment.log"
$VCFWorkloadDomainDeploymentJSONFile = "${VCFWorkloadDomainName}.json"
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
Write-Host -ForegroundColor Yellow "---- Workload Domain ----"
Write-Host -NoNewline -ForegroundColor Green "Name: "; Write-Host -ForegroundColor White $VCFWorkloadDomainName
Write-Host -NoNewline -ForegroundColor Green "ESXi Host: "; Write-Host -ForegroundColor White $ESXiHostFQDN
Write-Host -NoNewline -ForegroundColor Green "vCenter Server: "; Write-Host -ForegroundColor White "${VCSAHostname}.${VMDomain} (${VCSAIP})"
Write-Host -ForegroundColor Yellow "`n---- Shared/Existing NSX Manager ----"
Write-Host -NoNewline -ForegroundColor Green "VIP: "; Write-Host -ForegroundColor White "${NSXManagerVIPHostname}.${VMDomain} ($NSXManagerVIPIP)"
Write-Host -NoNewline -ForegroundColor Green "Node 1: "; Write-Host -ForegroundColor White "${NSXManagerNode1Hostname}.${VMDomain} ($NSXManagerNode1IP)"

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
# Build the Workload Domain creation spec
# ----------------------------------------------------------------------------
My-Logger "Generating Workload Domain deployment file $VCFWorkloadDomainDeploymentJSONFile ..."

# This lab host only has a single usable physical NIC (vmnic1).
$hostSpecs = @(
    [ordered]@{
        "id"         = $commissionedHost.id
        "licenseKey" = $ESXILicense
        "hostNetworkSpec" = @{
            "vmNics" = @(
                @{ "id" = "vmnic1"; "vdsName" = "$VCFWorkloadDomainName-cl01-vds01" }
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
            "datastoreName" = "$VCFWorkloadDomainName-cl01-vsan01"
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
            "datastoreName"      = "$VCFWorkloadDomainName-cl01-vsan01"
        }
    }
} else {
    My-Logger "Storage type '$ESXiHostStorageType' is not VSAN/VSAN_ESA - this script only builds vsanDatastoreSpec today." "red"
    My-Logger "Raw host object storage-related fields: datastoreType='$($commissionedHost.datastoreType)' compatibleStorageType='$($commissionedHost.compatibleStorageType)' hybrid='$($commissionedHost.hybrid)'" "red"
    exit
}

# The NSX overlay/transport config for this cluster (VLAN + TEP IP pool).
# Needed whether NSX Manager is new or shared, since it's specific to this
# cluster's hosts, not to the NSX Manager appliance itself.
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
    "domainName" = $VCFWorkloadDomainName
    "orgName"    = $VCFWorkloadDomainOrgName
    # Sharing the Management Domain's NSX Manager only works if this Workload
    # Domain has its own SSO domain (an "Isolated Domain"). Without this,
    # SDDC Manager tries to join the Management Domain's SSO/Enhanced-Linked-
    # Mode ring instead, which is rejected outright.
    "ssoDomainSpec" = @{
        "ssoDomainName"     = $SSODomainName
        "ssoDomainPassword" = $SSODomainPassword
    }
    "vcenterSpec" = @{
        "name" = $VCSAHostname
        "networkDetailsSpec" = @{
            "ipAddress"  = $VCSAIP
            "dnsName"    = "${VCSAHostname}.${VMDomain}"
            "gateway"    = $VMGateway
            "subnetMask" = $VMNetmask
        }
        "rootPassword"   = $VCSARootPassword
        "datacenterName" = $VCFDatacenterName
    }
    "computeSpec" = [ordered]@{
        "clusterSpecs" = @(
            [ordered]@{
                "name"           = "$VCFWorkloadDomainName-cl01"
                "clusterImageId" = $clusterImageId
                "hostSpecs"      = $hostSpecs
                "datastoreSpec"  = $datastoreSpec
                "networkSpec"   = @{
                    "vdsSpecs" = @(
                        [ordered]@{
                            "name" = "$VCFWorkloadDomainName-cl01-vds01"
                            "portGroupSpecs" = @(
                                @{ "name" = "$VCFWorkloadDomainName-cl01-vds01-management"; "transportType" = "MANAGEMENT" }
                                @{ "name" = "$VCFWorkloadDomainName-cl01-vds01-vmotion"; "transportType" = "VMOTION" }
                                @{ "name" = "$VCFWorkloadDomainName-cl01-vds01-vsan"; "transportType" = "VSAN" }
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
    # Pointing nsxTSpec at the EXISTING NSX Manager's real VIP/node details
    # (instead of details for brand-new nodes) is what tells SDDC Manager to
    # join that already-registered NSX Manager rather than deploy a new one.
    "nsxTSpec" = [ordered]@{
        "nsxManagerSpecs" = @(
            [ordered]@{
                "name" = $NSXManagerNode1Hostname
                "networkDetailsSpec" = @{
                    "ipAddress"  = $NSXManagerNode1IP
                    "dnsName"    = "${NSXManagerNode1Hostname}.${VMDomain}"
                    "gateway"    = $VMGateway
                    "subnetMask" = $VMNetmask
                }
            }
        )
        "vip"                     = $NSXManagerVIPIP
        "vipFqdn"                 = "${NSXManagerVIPHostname}.${VMDomain}"
        "licenseKey"              = $NSXLicense
        "nsxManagerAdminPassword" = $NSXManagerAdminPassword
    }
}

# Only add nodes 2 and 3 if the existing NSX Manager cluster actually has them
if ($NSXManagerNode2Hostname) {
    $payload.nsxTSpec.nsxManagerSpecs += [ordered]@{
        "name" = $NSXManagerNode2Hostname
        "networkDetailsSpec" = @{
            "ipAddress"  = $NSXManagerNode2IP
            "dnsName"    = "${NSXManagerNode2Hostname}.${VMDomain}"
            "gateway"    = $VMGateway
            "subnetMask" = $VMNetmask
        }
    }
}
if ($NSXManagerNode3Hostname) {
    $payload.nsxTSpec.nsxManagerSpecs += [ordered]@{
        "name" = $NSXManagerNode3Hostname
        "networkDetailsSpec" = @{
            "ipAddress"  = $NSXManagerNode3IP
            "dnsName"    = "${NSXManagerNode3Hostname}.${VMDomain}"
            "gateway"    = $VMGateway
            "subnetMask" = $VMNetmask
        }
    }
}

$LicenseLater = $true
if ($LicenseLater) {
    $evaluationMode = ($ESXILicense -eq "" -and $VSANLicense -eq "" -and $NSXLicense -eq "")
    $payload.add("deployWithoutLicenseKeys", $evaluationMode)
}

$payload | ConvertTo-Json -Depth 12 | Out-File -Force $VCFWorkloadDomainDeploymentJSONFile
My-Logger "Wrote $VCFWorkloadDomainDeploymentJSONFile"

# ----------------------------------------------------------------------------
# Validate the spec before submitting it for real. SDDC Manager runs this
# same check internally on creation anyway, but validating first lets us stop
# and show the actual errors instead of finding out after submission.
# ----------------------------------------------------------------------------
My-Logger "Validating Workload Domain spec against SDDC Manager ..."
$specBody = Get-Content -Raw $VCFWorkloadDomainDeploymentJSONFile
$validation = Invoke-SddcManagerApi -Method POST -Path "/v1/domains/validations" -Body $specBody -Token $accessToken

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
# Submit the Workload Domain for creation
# ----------------------------------------------------------------------------
My-Logger "Submitting Workload Domain deployment ..."
$wldDeployment = Invoke-SddcManagerApi -Method POST -Path "/v1/domains" -Body $specBody -Token $accessToken
My-Logger "Deployment submitted, task ID: $($wldDeployment.id)"
My-Logger "Open a browser to https://$sddcManagerFQDN to monitor deployment progress"

$EndTime = Get-Date
$duration = [math]::Round((New-TimeSpan -Start $StartTime -End $EndTime).TotalMinutes, 2)
My-Logger "Done. Took $duration minutes to look up host and submit Workload Domain deployment."
