# SDDC Manager Credentials
$SDDCManagerFQDN = "sddcm01.vcf.lab"
$SDDCManagerAdminPassword = "VMware1!VMware1!"

# Current & New password to set for the VCF Installer admin@local account
$VCFInstallerAdminOldPassword = 'CHANGEME-CHANGEME'
$VCFInstallerAdminNewPassword = 'CHANGEME-CHANGEME'

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

$payload = @{
    "username" = "admin@local"
    "password" = $SDDCManagerAdminPassword
}

$body = $payload | ConvertTo-Json

$headers = @{
    "Content-Type" = "application/json"
}

My-Logger "Retrieving access token from SDDC Manager ..."
$request = Invoke-WebRequest -Uri https://${SDDCManagerFQDN}/v1/tokens -Method POST -Body $body -Headers $headers -SkipCertificateCheck
if($request.StatusCode -eq 200) {
    $accesToken = ($request.Content | ConvertFrom-Json).accessToken
}

$headers += @{
    "Authorization" = "Bearer ${accesToken}"
}

$payload = @{
    oldPassword = $VCFInstallerAdminOldPassword
    newPassword = $VCFInstallerAdminNewPassword
}

$body = $payload | ConvertTo-Json

My-Logger "Updating password for VCF Installer local user: admin@local ..."
Invoke-WebRequest -Uri https://${SDDCManagerFQDN}/v1/users/local/admin -Method PATCH -Body $body -Headers $headers -SkipCertificateCheck
