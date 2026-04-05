# Author: William Lam
# Description: Automating various lab tweaks post-VCF deployment

# vCenter
$VCENTER_FQDN="vc01.vcf.lab"
$VCENTER_USERNAME="administrator@vsphere.local"
$VCENTER_PASSWORD='VMware1!VMware1!'

$clearVSANHealthAlarms = $true
$silenceVSANHealthFindings = $true
$disableAdmissionControl = $true

# NSX
$NSX_FQDN="nsx01.vcf.lab"
$NSX_USERNAME="admin"
$NSX_PASSWORD='VMware1!VMware1!'

$acceptEula = $true
$acceptCiep = $true
$updateUserPref = $true
$silenceAlarm = $true
$updateBackup = $true

#### DO NOT EDIT BEYOND HERE ####

Function My-Logger {
    param(
    [Parameter(Mandatory=$true)][String]$message,
    [Parameter(Mandatory=$false)][String]$color="green"
    )

    $timeStamp = Get-Date -Format "MM-dd-yyyy_hh:mm:ss"

    Write-Host -NoNewline -ForegroundColor White "[$timestamp]"
    Write-Host -ForegroundColor $color " $message"
    $logMessage = "[$timeStamp] $message"
}

if($clearVSANHealthAlarms -or $silenceVSANHealthFindings -or $disableAdmissionControl) {
    Connect-VIServer -Server ${VCENTER_FQDN} -User ${VCENTER_USERNAME} -Password ${VCENTER_PASSWORD} | Out-Null
}

if($clearVSANHealthAlarms) {
    My-Logger "Clearing vCenter vSAN Health Check Alarms ..."
    $alarmMgr = Get-View AlarmManager
    (Get-Cluster | where {$_.VsanEnabled -eq $true}) | where {$_.ExtensionData.TriggeredAlarmState} | %{
        $cluster = $_
        $Cluster.ExtensionData.TriggeredAlarmState | %{
            $alarmMgr.AcknowledgeAlarm($_.Alarm,$cluster.ExtensionData.MoRef)
        }
    }
    $alarmSpec = New-Object VMware.Vim.AlarmFilterSpec
    $alarmMgr.ClearTriggeredAlarms($alarmSpec)
}

if($silenceVSANHealthFindings) {
    My-Logger "Silencing vCenter vSAN Health Findings ..."

    $cluster = Get-Cluster | where {$_.VsanEnabled -eq $true}

    $vchs = Get-VSANView -Id "VsanVcClusterHealthSystem-vsan-cluster-health-system"
    $results = $vchs.VsanQueryVcClusterHealthSummary(($cluster.ExtensionData.MoRef),$null, $null, $null, $null, $null, $null, $null, $null)
    foreach ($group in $results.Groups) {
        if($group.GroupHealth -eq "yellow") {
            $silentChecks = @()
            foreach ($groupTest in $group.GroupTests) {
                if($groupTest.TestHealth -eq "yellow") {
                    $silentChecks += $groupTest.TestId.replace("com.vmware.vsan.health.test.","")
                }
            }
            $results = $vchs.VsanHealthSetVsanClusterSilentChecks(($cluster.ExtensionData.MoRef),$silentChecks,$null)
        }
    }
}

if($disableAdmissionControl) {
    My-Logger "Disabling vCenter vSphere HA Admission Control ..."

    $cluster = Get-Cluster | where {$_.VsanEnabled -eq $true}

    $dasSpec = New-Object VMware.Vim.ClusterDasConfigInfo
    $dasSpec.admissionControlEnabled = $false

    $spec = New-Object VMware.Vim.ClusterConfigSpecEx
    $spec.dasConfig = $dasSpec

    $task = $cluster.ExtensionData.ReconfigureComputeResource_Task($spec, $true)
    $task1 = Get-Task -Id ("Task-$($task.value)")
    $task1 | Wait-Task | Out-Null
}

if($clearVSANHealthAlarms -or $silenceVSANHealthFindings -or $disableAdmissionControl) {
    Disconnect-VIServer -Server ${VCENTER_FQDN} -Confirm:$false | Out-Null
}

if($acceptEula -or $acceptCiep -or $updateUserPref -or $silenceAlarm -or $updateBackup) {
    $pair = "${NSX_USERNAME}:${NSX_PASSWORD}"
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
    $encoded = [Convert]::ToBase64String($bytes)

    $headers = @{
        Authorization = "Basic $encoded"
        "Content-Type" = "application/json"
    }
}

if($acceptEula ) {
    My-Logger "Accepting NSX EULA Agreement ..."
    $requests = Invoke-WebRequest -Uri "https://${NSX_FQDN}/api/v1/telemetry/agreement" -Method GET -Headers $headers -SkipCertificateCheck
    if($requests.StatusCode -eq 200) {
        $spec = $requests.Content | ConvertFrom-Json
        $spec.telemetry_agreement_displayed = $false
        $body = $spec | ConvertTo-Json
        $requests = Invoke-WebRequest -Uri "https://${NSX_FQDN}/api/v1/telemetry/agreement" -Method PUT -Headers $headers -Body $body -SkipCertificateCheck
    }
}

if($acceptCiep) {
    My-Logger "Accepting NSX EIP Agreement ..."
    $requests = Invoke-WebRequest -Uri "https://${NSX_FQDN}/api/v1/telemetry/config" -Method GET -Headers $headers -SkipCertificateCheck
    if($requests.StatusCode -eq 200) {
        $spec = $requests.Content | ConvertFrom-Json
        $spec.ceip_acceptance = $true
        $body = $spec | ConvertTo-Json
        $requests = Invoke-WebRequest -Uri "https://${NSX_FQDN}/api/v1/telemetry/config" -Method PUT -Headers $headers -Body $body -SkipCertificateCheck
    }
}

if($updateUserPref) {
    My-Logger "Updating NSX User Preferences ..."
    $requests = Invoke-WebRequest -Uri "https://${NSX_FQDN}/api/v1/user-preferences" -Method GET -Headers $headers -SkipCertificateCheck
    if($requests.StatusCode -eq 200) {
        $spec = $requests.Content | ConvertFrom-Json
        $spec.other_preferences[1].value = $false
        $body = $spec | ConvertTo-Json
        $requests = Invoke-WebRequest -Uri "https://${NSX_FQDN}/api/v1/user-preferences" -Method PUT -Headers $headers -Body $body -SkipCertificateCheck
    }
}

if($silenceAlarm) {
    My-Logger "Disabling annoying NSX alarms ..."
    $requests = Invoke-WebRequest -Uri "https://${NSX_FQDN}/api/v1/events/logging.remote_logging_not_configured" -Method GET -Headers $headers -SkipCertificateCheck
    if($requests.StatusCode -eq 200) {
        $spec = $requests.Content | ConvertFrom-Json
        $spec.is_disabled = $true
        $body = $spec | ConvertTo-Json
        $requests = Invoke-WebRequest -Uri "https://${NSX_FQDN}/api/v1/events/logging.remote_logging_not_configured" -Method PUT -Headers $headers -Body $body -SkipCertificateCheck
    }

    $requests = Invoke-WebRequest -Uri "https://${NSX_FQDN}/api/v1/events/capacity.minimum_capacity_threshold" -Method GET -Headers $headers -SkipCertificateCheck
    if($requests.StatusCode -eq 200) {
        $spec = $requests.Content | ConvertFrom-Json
        $spec.is_disabled = $true
        $body = $spec | ConvertTo-Json
        $requests = Invoke-WebRequest -Uri "https://${NSX_FQDN}/api/v1/events/capacity.minimum_capacity_threshold" -Method PUT -Headers $headers -Body $body -SkipCertificateCheck
    }
}

if($updateBackup) {
    My-Logger "Updating NSX backup schedule ..."
    $requests = Invoke-WebRequest -Uri "https://${NSX_FQDN}/api/v1/cluster/backups/config" -Method GET -Headers $headers -SkipCertificateCheck
    if($requests.StatusCode -eq 200) {
        $spec = $requests.Content | ConvertFrom-Json
        $spec.backup_schedule.seconds_between_backups = 43200
        $body = $spec | ConvertTo-Json -Depth 3
        $requests = Invoke-WebRequest -Uri "https://${NSX_FQDN}/api/v1/cluster/backups/config" -Method PUT -Headers $headers -Body $body -SkipCertificateCheck
    }
}