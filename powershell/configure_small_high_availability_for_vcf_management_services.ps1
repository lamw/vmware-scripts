# VCF Management Services (VCFMS) Crededntials
$VCFManagementServicesRuntimeFQDN = "vcf-msr01.vcf.lab"
$VCFManagementServicesPassword = "VMware1!VMware1!"
$VCFManagementServicesComponentID = ""

$ValidateOnly = $true # change to false to deploy
$RestartFleetLcm = $false # change to true to restart Fleet LCM service after enabling VCFMS HA

### DO NOT EDIT BEYOND HERE ###

$vcfmsHaMode = $false

Function My-Logger {
    param(
        [Parameter(Mandatory=$true)][String]$message,
        [Parameter(Mandatory=$false)][String]$color="green"
    )


    $timeStamp = Get-Date -Format "MM-dd-yyyy_hh:mm:ss"


    Write-Host -NoNewline -ForegroundColor White "[$timestamp]"
    Write-Host -ForegroundColor $color " $message"
}

Function Wait-VCFMSTask {
    param(
        [Parameter(Mandatory=$true)][String]$TaskId,
        [Parameter(Mandatory=$true)][String]$AccessToken,
        [Parameter(Mandatory=$true)][String]$RuntimeFQDN,
        [Parameter(Mandatory=$false)][String]$TaskLabel="Task",
        [Parameter(Mandatory=$false)][Int]$PollIntervalSeconds=60
    )

    $terminalPhases = @('Succeeded', 'Failed', 'Canceled', 'Cancelled')
    $latestTask = $null
    $phase = $null

    $pollIntervalDisplay = if ($PollIntervalSeconds -ge 60) {
        "${PollIntervalSeconds} seconds ($([math]::Round($PollIntervalSeconds / 60, 2)) minute(s))"
    } else {
        "${PollIntervalSeconds} seconds"
    }

    My-Logger "${TaskLabel} submitted: ${TaskId}. Poll interval: ${pollIntervalDisplay}." "cyan"

    do {
        $taskParams = @{
            Uri                  = "https://${RuntimeFQDN}/api/v1/tasks/${TaskId}"
            Method               = 'GET'
            Headers              = @{
                'Content-Type'  = 'application/json'
                'Authorization' = "Bearer ${AccessToken}"
            }
            SkipCertificateCheck = $true
        }

        $taskRequest = Invoke-WebRequest @taskParams
        $latestTask = ($taskRequest.Content | ConvertFrom-Json)

        $phase = if ($latestTask.phase) { $latestTask.phase } else { $latestTask.status }
        $stageSummary = ""
        if ($latestTask.stages) {
            $stageSummary = ($latestTask.stages | ForEach-Object { "{0}={1}" -f $_.name, $_.status }) -join "; "
        }

        if ($stageSummary) {
            My-Logger "${TaskLabel} ${TaskId} phase=${phase}; stages: ${stageSummary}" "yellow"
        } else {
            My-Logger "${TaskLabel} ${TaskId} phase=${phase}" "yellow"
        }

        if ($terminalPhases -notcontains $phase) {
            My-Logger "${TaskLabel} ${TaskId} not finished. Next poll in ${pollIntervalDisplay}." "cyan"
            Start-Sleep -Seconds $PollIntervalSeconds
        }
    } while ($terminalPhases -notcontains $phase)

    if ($phase -ne 'Succeeded') {
        My-Logger "${TaskLabel} ${TaskId} finished with phase ${phase}" "red"
        if ($latestTask.messages) {
            My-Logger "Task messages:" "red"
            $latestTask.messages | ConvertTo-Json -Depth 10
        }
        throw "${TaskLabel} did not succeed."
    }

    My-Logger "${TaskLabel} ${TaskId} completed successfully." "green"
    return $latestTask
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

if($ValidateOnly -eq $true) {
    My-Logger "### VALIDATION MODE ONLY ###" "cyan"

    # Retrieve VCFMS Component ID
    My-Logger "Retrieving VCFMS Configuration ..."
    $connectivityParams = @{
        Uri                  = "https://${VCFManagementServicesRuntimeFQDN}/api/v1/components?type=vsp"
        Method               = 'GET'
        Headers              = @{
            'Content-Type'  = 'application/json'
            'Authorization' = "Bearer ${accessToken}"
        }
        Body                = $body
        SkipCertificateCheck = $true
    }

    $request = Invoke-WebRequest @connectivityParams
    if($request.StatusCode -eq 200) {
        $components = ($request.Content | ConvertFrom-Json).components

        $components |
            Select-Object @(
                @{Name='FQDN'; Expression={$_.spec.configuration.ingress.platform.fqdn}}
                @{Name='Size'; Expression={$_.spec.configuration.size}}
                @{Name='HA'; Expression={$_.spec.configuration.cluster.ha}}
                @{Name='ComponentId'; Expression={$_.id}}
            )
    }
}

if($ValidateOnly -eq $false -and $VCFManagementServicesComponentID -ne "") {
    $payload = @{
        spec = @{
            configuration = @{
                cluster = @{
                    ha = $vcfmsHaMode
                }
            }
        }
    }

    $body = $payload | ConvertTo-Json -Depth 5

    $connectivityParams = @{
        Uri                  = "https://${VCFManagementServicesRuntimeFQDN}/api/v1/components/${VCFManagementServicesComponentID}?action=apply"
        Method               = 'POST'
        Headers              = @{
            'Content-Type'  = 'application/json'
            'Authorization' = "Bearer ${accessToken}"
        }
        Body                = $body
        SkipCertificateCheck = $true
    }

    $haOperation = if ($vcfmsHaMode) { "Enabling" } else { "Disabling" }
    My-Logger "${haOperation} VCFMS High Availability ..."
    $request = Invoke-WebRequest @connectivityParams

    $taskResponse = ($request.Content | ConvertFrom-Json)
    $taskId = $taskResponse.id

    if (-not $taskId) {
        throw "Unable to retrieve task ID from apply response."
    }

    $applyPollingIntervalSeconds = 300
    $latestTask = Wait-VCFMSTask -TaskId $taskId -AccessToken $accessToken -RuntimeFQDN $VCFManagementServicesRuntimeFQDN -TaskLabel "VCFMS availability update task" -PollIntervalSeconds $applyPollingIntervalSeconds
    $latestTask
}

if($ValidateOnly -eq $false -and $RestartFleetLcm) {
    My-Logger "Retrieving Fleet LCM Service and Restarting ..."
    $connectivityParams = @{
        Uri                  = "https://${VCFManagementServicesRuntimeFQDN}/api/v1/components?type=vcf-fleet-lcm"
        Method               = 'GET'
        Headers              = @{
            'Content-Type'  = 'application/json'
            'Authorization' = "Bearer ${accessToken}"
        }
        Body                = $body
        SkipCertificateCheck = $true
    }

    $request = Invoke-WebRequest @connectivityParams
    if($request.StatusCode -eq 200) {
        $fleetLcm = ($request.Content | ConvertFrom-Json).components

        $connectivityParams = @{
            Uri                  = "https://${VCFManagementServicesRuntimeFQDN}/api/v1/components/$(${fleetLcm}.id)?action=restart"
            Method               = 'POST'
            Headers              = @{
                'Content-Type'  = 'application/json'
                'Authorization' = "Bearer ${accessToken}"
            }
            SkipCertificateCheck = $true
        }

        $request = Invoke-WebRequest @connectivityParams
        $taskResponse = ($request.Content | ConvertFrom-Json)
        $taskId = $taskResponse.id

        if (-not $taskId) {
            throw "Unable to retrieve task ID from Fleet LCM restart response."
        }

        $restartPollingIntervalSeconds = 60
        $latestTask = Wait-VCFMSTask -TaskId $taskId -AccessToken $accessToken -RuntimeFQDN $VCFManagementServicesRuntimeFQDN -TaskLabel "Fleet LCM restart task" -PollIntervalSeconds $restartPollingIntervalSeconds
    }
}
