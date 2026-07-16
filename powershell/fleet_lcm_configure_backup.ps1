# VCF Instance Name
$VCFInstanceName = "VMUG x Intel x Micron VCF 9.1 Instance"

# VCF Management Services (VCFMS) Credentials
$VCFManagementServicesPassword = "VMware1!VMware1!"
$VCFManagementServicesRuntimeFQDN = "vcf-msr01.vcf.lab"
$VCFManagementServicesFleetFQDN = "vcf-flt01.vcf.lab"

# Backup Configuration
$daysToBackup = @("MON","TUE","WED","THU","FRI","SAT","SUN")
$startTime = "10:00Z" # Zula format (UTC)
$sftpServer = "vis.vcf.lab"
$sftpServerPort = "22"
$sftpServerUsername = "backup"
$sftpServerPassword = "VMware1!"
$sftpServerBackupDirectory = "/backup"
$sftpServerEncryptionPassword = "VMware1!VMware1!"
# Need to manually run ssh-keyscan -p $sftpServerPort $sftpServer 2>$null | Select-Object -First 1
$sftpServerHostKey = ''

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

function Get-SshKeyFingerprint {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SshKeyLine
    )

    $parts = $SshKeyLine.Trim() -split '\s+', 3
    if ($parts.Count -lt 3) {
        throw "Invalid SSH public key line. Expected: <host> <key-type> <base64-key>"
    }

    $keyBytes = [Convert]::FromBase64String($parts[2])
    $sha256 = [System.Security.Cryptography.SHA256]::Create()

    try {
        $hashBytes = $sha256.ComputeHash($keyBytes)
    }
    finally {
        $sha256.Dispose()
    }

    return 'SHA256:' + [Convert]::ToBase64String($hashBytes).TrimEnd('=')
}

Function Wait-VCFTaskCompletion {
    param(
        [Parameter(Mandatory=$true)][String]$FleetFqdn,
        [Parameter(Mandatory=$true)][String]$AccessToken,
        [Parameter(Mandatory=$true)][String]$TaskId,
        [Parameter(Mandatory=$false)][Int]$PollIntervalSec = 5,
        [Parameter(Mandatory=$false)][Int]$TimeoutSec = 1800
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    $lastStatus = ""

    while ((Get-Date) -lt $deadline) {
        $taskParams = @{
            Uri                  = "https://${FleetFqdn}/fleet-lcm/v1/tasks/${TaskId}"
            Method               = 'GET'
            Headers              = @{
                'Content-Type'  = 'application/json'
                'Authorization' = "Bearer ${AccessToken}"
            }
            SkipCertificateCheck = $true
        }

        $taskResponse = Invoke-WebRequest @taskParams
        if ($taskResponse.StatusCode -ne 200) {
            throw "Failed to query task ${TaskId}. HTTP status code: $($taskResponse.StatusCode)"
        }

        $task = $taskResponse.Content | ConvertFrom-Json
        $status = [string]$task.status

        if ($status -ne $lastStatus) {
            My-Logger "Task ${TaskId} status: ${status}" "yellow"
            $lastStatus = $status
        }

        if ($status -eq 'SUCCEEDED') {
            return $task
        }

        if ($status -in @('FAILED','CANCELLED')) {
            $failureDetails = Get-VCFTaskFailureMessages -Task $task

            if ($failureDetails.Count -gt 0) {
                My-Logger "Task ${TaskId} reported the following validation errors:" "red"
                foreach ($detail in $failureDetails) {
                    My-Logger "  - $detail" "red"
                }
                throw "Task ${TaskId} finished with terminal state: ${status}. Reason: $($failureDetails[0])"
            }

            if ($task.additionalDetails -and $task.additionalDetails.PSObject.Properties.Count -gt 0) {
                try {
                    $additionalDetailsJson = $task.additionalDetails | ConvertTo-Json -Depth 10 -Compress
                    My-Logger "Task ${TaskId} additionalDetails: ${additionalDetailsJson}" "red"
                }
                catch {
                    My-Logger "Task ${TaskId} additionalDetails could not be serialized." "red"
                }
            }

            try {
                $taskSnapshot = $task | ConvertTo-Json -Depth 10 -Compress
                My-Logger "Task ${TaskId} full payload: ${taskSnapshot}" "red"
            }
            catch {
                My-Logger "Task ${TaskId} full payload could not be serialized." "red"
            }

            throw "Task ${TaskId} finished with terminal state: ${status}. No detailed error message was returned by Tasks API."
        }

        Start-Sleep -Seconds $PollIntervalSec
    }

    throw "Timed out waiting for task ${TaskId} to complete after ${TimeoutSec} seconds"
}

Function Get-VCFTaskFailureMessages {
    param(
        [Parameter(Mandatory=$true)]$Task
    )

    $messages = @()

    if ($Task.messages) {
        foreach ($entry in $Task.messages) {
            $level = [string]$entry.level
            $msgId = [string]$entry.message.id
            $msgText = [string]$entry.message.localizedMessage
            if (-not $msgText) {
                $msgText = [string]$entry.message.defaultMessage
            }

            if ($msgText) {
                $messages += "[TASK][$level][$msgId] $msgText"
            }
        }
    }

    if ($Task.stages) {
        foreach ($stage in $Task.stages) {
            $stageName = [string]$stage.name
            if (-not $stageName) {
                $stageName = [string]$stage.id
            }

            if ($stage.messages) {
                foreach ($entry in $stage.messages) {
                    $level = [string]$entry.level
                    $msgId = [string]$entry.message.id
                    $msgText = [string]$entry.message.localizedMessage
                    if (-not $msgText) {
                        $msgText = [string]$entry.message.defaultMessage
                    }

                    $argsText = ""
                    if ($entry.message.args) {
                        try {
                            $pairs = @()
                            foreach ($prop in $entry.message.args.PSObject.Properties) {
                                $pairs += "$($prop.Name)=$($prop.Value)"
                            }
                            if ($pairs.Count -gt 0) {
                                $argsText = " | args: " + ($pairs -join ", ")
                            }
                        }
                        catch {
                            # Ignore argument parsing errors and keep output readable.
                        }
                    }

                    if ($msgText) {
                        $messages += "[STAGE:$stageName][$level][$msgId] $msgText$argsText"
                    }
                }
            }
        }
    }

    return $messages
}

# --- Authentication ---
$authParams = @{
    Uri                  = "https://${VCFManagementServicesRuntimeFQDN}/api/v1/identity/token"
    Method               = 'POST'
    Headers              = @{
        'Content-Type' = 'application/x-www-form-urlencoded'
    }
    SkipCertificateCheck = $true
    Body                 = @{
        grant_type = 'password'
        username   = "admin@vsp.local"
        password   = $VCFManagementServicesPassword
    }
}

$authResponse = Invoke-WebRequest @authParams

if ($authResponse.StatusCode -eq 200) {
    $accessToken = ($authResponse.Content | ConvertFrom-Json).access_token
} else {
    Write-Error "Failed to authenticate. Status Code: $($authResponse.StatusCode)"
    return
}

# --- Retrieve SDDC LCM ID ---
$connectivityParams = @{
    Uri                  = "https://${VCFManagementServicesFleetFQDN}/fleet-lcm/v1/sddc-lcms"
    Method               = 'GET'
    Headers              = @{
        'Content-Type'  = 'application/json'
        'Authorization' = "Bearer ${accessToken}"
    }
    SkipCertificateCheck = $true
}

$request = Invoke-WebRequest @connectivityParams

$sddcLcmId = (($request.Content | ConvertFrom-Json).sddcLcms | where {$_.sddcGroupName -eq $VCFInstanceName}).id
if($sddcLcmId -eq $null) {
    Write-Error "Unable to locate SDDC LCM ID based on VCF Instance Label: ${VCFInstanceName}"
    return
}

$sshThumbprint = Get-SshKeyFingerprint -SshKeyLine $sftpServerHostKey

$payload = @{
    backupConfigSpec = [ordered]@{
    fullSchedule = [ordered]@{
        enabled = $true
        schedule= [ordered]@{
            days = @($daysToBackup)
            startTime = $startTime
        }
    }
    incrementalSchedule = @{
        enabled = $false
    }
    retention = @{}
    storage = [ordered]@{
        sftp = [ordered]@{
            host = $sftpServer
            port = $sftpServerPort
            username = $sftpServerUsername
            password = $sftpServerPassword
            directory =  $sftpServerBackupDirectory
            thumbprint = $sshThumbprint
        }
    }
    encryptionPassphrase = $sftpServerEncryptionPassword
    }
}

$body = $payload | ConvertTo-Json -Depth 12

if($OutputJsonPayload) {
    $body
}

if($ValidateOnly) {
    My-Logger "### VALIDATION MODE ONLY ###" "cyan"
}

if($ValidateOnly -eq $false) {
    My-Logger "Creating Backup Schedule Configuration for VCF Instance ${VCFInstanceName} ..."
    $connectivityParams = @{
        Uri                  = "https://${VCFManagementServicesFleetFQDN}/fleet-lcm/v1/sddc-lcms/${sddcLcmId}"
        Method               = 'PATCH'
        Headers              = @{
            'Content-Type'  = 'application/json'
            'Authorization' = "Bearer ${accessToken}"
        }
        Body                = $body
        SkipCertificateCheck = $true
    }
    Invoke-WebRequest @connectivityParams
}
