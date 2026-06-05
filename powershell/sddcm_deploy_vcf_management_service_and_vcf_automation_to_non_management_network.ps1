# SDDC Manager Credentials
$SDDCManagerFQDN = "sddcm02.vcf.lab"
$SDDCManagerAdminPassword = "VMware1!VMware1!"

# VCF Operations Credentials
$VCFOperationsFQDN = "vcf02.vcf.lab"
$VCFOperationsAdminPassword = "VMware1!VMware1!"

# License Server & Identity Brokder FQDN
$VCFLicenseServerFQDN = "vcf-lic03.vcf.lab"
$VCFIdentityBrokerFQDN = "vcf-idb03.vcf.lab"

# VCF Management Services (VCFMS) Configurations
$VCFManagementServicesSize = "small" #small medium large
$VCFManagementServicesPassword = "VMware1!VMware1!"
$VCFManagementServicesRuntimeFQDN = "vcf-msr03.vcf.lab"
$VCFManagementServicesFleetFQDN = "vcf-flt03.vcf.lab"
$VCFManagementServicesInstanceFQDN = "vcf-int03.vcf.lab"
$VCFManagementServicesIps = @("172.30.70.170","172.30.70.172","172.30.70.173","172.30.70.174","172.30.70.175","172.30.70.176","172.30.70.177","172.30.70.178","172.30.70.179","172.30.70.180","172.30.70.181","172.30.70.182") # Minimum of 12 IPs
$VCFManagementServicesInternalClusterCIDR = "198.18.0.0/15" # leave default, this is for internal communication for Cluster CIDR

$VCFAutomationFQDN = "auto03.vcf.lab"
$VCFAutomationServicesPassword = "VMware1!VMware1!"
$VCFAutomationSize = "small"
$VCFAutomationRuntimeFQDN = "vcf-asr03.vcf.lab"
$VCFAutomationServicesIps = @("172.30.70.65","172.30.70.66","172.30.70.67","172.30.70.68","172.30.70.69") # Minimum of 5 IPs & Maximum of 5 IPs
$VCFAutomationServicesInternalClusterCIDR = "198.18.0.0/15"

# Network to place VCF Management Services
$VCFManagementServicesNetworkName = "DVPG_FOR_FLEET_MANAGEMENT" # vSphere UI label for DVPG or NSX Overlay
$VCFManagementServicesNetworkNetmask = "255.255.255.0"
$VCFManagementServicesNetworkGateway = "172.30.70.1"

$ValidateOnly = $true # change to false to deploy
$OutputJsonPayload = $false # change to true to output to PS console (can be used without deployment)

### DO NOT EDIT BEYOND HERE ###

Function My-Logger {
    param(
        [Parameter(Mandatory=$true)][String]$message,
        [Parameter(Mandatory=$false)][String]$color="green"
    )


    $timeStamp = Get-Date -Format "MM-dd-yyyy_hh:mm:ss"


    Write-Host -NoNewline -ForegroundColor White "[$timestamp]"
    Write-Host -ForegroundColor $color " $message"
}

Function Get-TlsCertificateSha256Fingerprint {
    param(
        [Parameter(Mandatory = $true)][string]$HostName,
        [Parameter(Mandatory = $false)][int]$Port = 443,
        [Parameter(Mandatory = $false)][int]$TimeoutMs = 10000
    )

    $tcpClient = $null
    $sslStream = $null

    try {
        $tcpClient = [System.Net.Sockets.TcpClient]::new()
        $connectTask = $tcpClient.ConnectAsync($HostName, $Port)
        if (-not $connectTask.Wait($TimeoutMs)) {
            throw "Timed out connecting to ${HostName}:${Port}"
        }

        $sslStream = [System.Net.Security.SslStream]::new(
            $tcpClient.GetStream(),
            $false,
            { param($sender, $certificate, $chain, $sslPolicyErrors) return $true }
        )
        $sslStream.AuthenticateAsClient($HostName)

        if (-not $sslStream.RemoteCertificate) {
            throw "No remote certificate was presented by ${HostName}:${Port}"
        }

        $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($sslStream.RemoteCertificate)
        $hashBytes = [System.Security.Cryptography.SHA256]::HashData($cert.RawData)
        return ([BitConverter]::ToString($hashBytes)).Replace('-', ':').ToUpperInvariant()
    }
    finally {
        if ($sslStream) { $sslStream.Dispose() }
        if ($tcpClient) { $tcpClient.Dispose() }
    }
}

$vcf02Sha256 = Get-TlsCertificateSha256Fingerprint -HostName $VCFOperationsFQDN

$payload = @{
    "username" = "admin@local"
    "password" = $SDDCManagerAdminPassword
}

$body = $payload | ConvertTo-Json

$headers = @{
    "Content-Type" = "application/json"
}

if($ValidateOnly) {
    My-Logger "### VALIDATION MODE ONLY ###" "cyan"
}

My-Logger "Retrieving access token from SDDC Manager ..."
$request = Invoke-WebRequest -Uri https://${SDDCManagerFQDN}/v1/tokens -Method POST -Body $body -Headers $headers -SkipCertificateCheck
if($request.StatusCode -eq 200) {
    $accesToken = ($request.Content | ConvertFrom-Json).accessToken
}

$headers += @{
    "Authorization" = "Bearer ${accesToken}"
}

$payload = [ordered]@{
    vcfOperationsSpec = [ordered]@{
        "nodes" = @(
            @{
                hostname = $VCFOperationsFQDN
                type = "master"
                sslThumbprint = $vcf02Sha256
            }
        )
        adminUserPassword = $VCFOperationsAdminPassword
        loadBalancerFqdn = ""
        useExistingDeployment = $true
    }
    vspClusterSpec = [ordered]@{
        platformFqdn = $VCFManagementServicesRuntimeFQDN
        systemUserPassword = $VCFManagementServicesPassword
        ipv4Pool = @{
            addresses = $VCFManagementServicesIps
        }
        size = $VCFManagementServicesSize
        internalClusterCidrIpv4 = $VCFManagementServicesInternalClusterCIDR
        instanceFqdn = $VCFManagementServicesInstanceFQDN
        fleetFqdn = $VCFManagementServicesFleetFQDN
        useExistingDeployment = $false
    }
    vcfManagementComponentsInfrastructureSpec = [ordered]@{
        localRegionNetwork = [ordered]@{
            networkName = $VCFManagementServicesNetworkName
            subnetMask = $VCFManagementServicesNetworkNetmask
            gateway = $VCFManagementServicesNetworkGateway
        }
        xRegionNetwork = [ordered]@{
            networkName = $VCFManagementServicesNetworkName
            subnetMask = $VCFManagementServicesNetworkNetmask
            gateway = $VCFManagementServicesNetworkGateway
        }
    }
    licenseServerSpec = @{hostname = $VCFLicenseServerFQDN}
    vidbSpec = @{hostname = $VCFIdentityBrokerFQDN}
    fleetLcmSpec = @{}
    sddcLcmSpec = @{}
    fleetDepotSpec = @{}
    telemetryAcceptorSpec = @{}
    saltSpec = @{}
    saltRaasSpec = @{}
    vcfAutomationSpec = [ordered]@{
        hostname = $VCFAutomationFQDN
        platformFqdn = $VCFAutomationRuntimeFQDN
        adminUserPassword = $VCFAutomationServicesPassword
        ipPool = $VCFAutomationServicesIps
        internalClusterCidr = $VCFAutomationServicesInternalClusterCIDR
        nodePrefix = "vcf-m01-node-01"
        size = $VCFAutomationSize
    }
}

$body = $payload | ConvertTo-Json -Depth 10

if($OutputJsonPayload) {
    $body
}

try {
    My-Logger "Starting VCF Management Services (VCFMS) and VCF Automation (VCFA) Deployment Validation ..."
    $request = Invoke-WebRequest -Uri https://${SDDCManagerFQDN}/v1/vcf-management-components/validations -Method POST -Body $body -Headers $headers -SkipCertificateCheck -ErrorAction Stop
    $taskId = ($request.Content | ConvertFrom-Json).id

    if ([string]::IsNullOrWhiteSpace($taskId)) {
        throw "Validation task id was not returned by the API. Response: $($request.Content)"
    }

    My-Logger "Validation task id: ${taskId}"

    $executionPendingStates = @("PENDING", "IN_PROGRESS", "RUNNING", "QUEUED")
    $executionFailureStates = @("FAILED", "ERROR", "CANCELED", "CANCELLED")
    $resultSuccessStates = @("PASSED", "SUCCESS", "SUCCEEDED", "SUCCESSFUL")
    $resultFailureStates = @("FAILED", "ERROR", "CANCELED", "CANCELLED")

    do {
        $request = Invoke-WebRequest -Uri "https://${SDDCManagerFQDN}/v1/vcf-management-components/validations/${taskId}" -Method GET -Headers $headers -SkipCertificateCheck -ErrorAction Stop
        $task = $request.Content | ConvertFrom-Json

        $executionStatus = [string]$task.executionStatus
        if ([string]::IsNullOrWhiteSpace($executionStatus)) {
            $executionStatus = [string]$task.status
        }

        $resultStatus = [string]$task.resultStatus

        if ([string]::IsNullOrWhiteSpace($executionStatus)) {
            throw "Validation task status was missing. Response: $($request.Content)"
        }

        if ([string]::IsNullOrWhiteSpace($resultStatus)) {
            My-Logger "Validation task executionStatus: ${executionStatus}" "yellow"
        }
        else {
            My-Logger "Validation task executionStatus: ${executionStatus}, resultStatus: ${resultStatus}" "yellow"
        }

        if ($executionPendingStates -contains $executionStatus.ToUpperInvariant()) {
            Start-Sleep -Seconds 10
            continue
        }

        if ($executionFailureStates -contains $executionStatus.ToUpperInvariant()) {
            My-Logger "Validation failed with executionStatus ${executionStatus}." "red"
            throw "Validation task ${taskId} failed with executionStatus ${executionStatus}."
        }

        if ($executionStatus.ToUpperInvariant() -eq "COMPLETED") {
            if ([string]::IsNullOrWhiteSpace($resultStatus)) {
                My-Logger "Validation completed but resultStatus was missing." "red"
                throw "Validation task ${taskId} completed without resultStatus."
            }

            if ($resultSuccessStates -contains $resultStatus.ToUpperInvariant()) {
                My-Logger "Validation completed successfully." "green"
                break
            }

            if ($resultFailureStates -contains $resultStatus.ToUpperInvariant()) {
                My-Logger "Validation failed with resultStatus ${resultStatus}." "red"

                $allChecks = @($task.validationChecks)

                if ($allChecks.Count -gt 0) {
                    My-Logger "Validation checks ($($allChecks.Count))" "red"
                    $index = 1

                    foreach ($check in $allChecks) {
                        $description = [string]$check.description
                        if ([string]::IsNullOrWhiteSpace($description)) {
                            $description = "No description provided"
                        }

                        $remediation = "No remediation provided"
                        if ($check.errorResponse -and -not [string]::IsNullOrWhiteSpace([string]$check.errorResponse.remediationMessage)) {
                            $remediation = [string]$check.errorResponse.remediationMessage
                        }

                        Write-Host -ForegroundColor Cyan ("`t{0}. {1}" -f $index, $description)
                        Write-Host -ForegroundColor Cyan ("`t`tremediation: {0}" -f $remediation)
                        $index++
                    }
                }
                else {
                    My-Logger "Validation failed but no validationChecks were returned." "red"
                }

                throw "Validation failed for task ${taskId} with resultStatus ${resultStatus}. See validation checks above."
            }

            My-Logger "Validation completed with unexpected resultStatus '${resultStatus}'." "yellow"
            throw "Validation task ${taskId} completed with unexpected resultStatus ${resultStatus}."
        }

        My-Logger "Validation returned unexpected executionStatus '${executionStatus}'." "yellow"
        throw "Validation task ${taskId} returned unexpected executionStatus ${executionStatus}."
    } while ($true)
}
catch {
    My-Logger "Validation request failed: $($_.Exception.Message)" "red"

    if ($_.Exception.Response -and $_.Exception.Response.Content) {
        try {
            $errorBody = $_.Exception.Response.Content.ReadAsStringAsync().Result
            if ($errorBody) {
                My-Logger "HTTP error response body:" "red"
                Write-Host $errorBody
            }
        }
        catch {
            My-Logger "Unable to read HTTP error response body." "red"
        }
    }

    throw
}

if($ValidateOnly -eq $false) {
    My-Logger "Starting VCF Management Services (VCFMS) and VCF Automation (VCFA) Deployment to alternative network ${VCFManagementServicesNetworkName} ..."
    Invoke-WebRequest -Uri https://${SDDCManagerFQDN}/v1/vcf-management-components -Method POST -Body $body -Headers $headers -SkipCertificateCheck
}
