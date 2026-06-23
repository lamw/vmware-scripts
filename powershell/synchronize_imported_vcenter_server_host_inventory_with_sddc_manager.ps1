# SDDC Manager Credentials
$SDDCManagerFQDN = "sddcm01.vcf.lab"
$SDDCManagerAdminPassword = "VMware1!VMware1!"
$DomainIdToSynchronize = ""
$DomainNameToSynchronize = ""
$ValidateOnly = $true

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

if($ValidateOnly) {
    My-Logger "### VALIDATION MODE ONLY ###" "cyan"

    My-Logger "Listing VCF Domains ..."
    $request = Invoke-WebRequest -Uri https://${SDDCManagerFQDN}/v1/domains -Method GET -Headers $headers -SkipCertificateCheck

    if($request.StatusCode -eq 200) {
        $domains = ($request.Content | ConvertFrom-json).elements

        $domains | select name, type, id
    }
} else {
    My-Logger "Synchronizing VCF Domain ${DomainNameToSynchronize} (${DomainIdToSynchronize}) ..."

    $payload = @{
        domainName = $DomainNameToSynchronize
        skipEsxThumbprintValidation = $false
    }

    $body = $payload | ConvertTo-Json

    Invoke-WebRequest -Uri https://${SDDCManagerFQDN}/v1/domains/${DomainIdToSynchronize}/synchronizations -Method POST -Headers $headers -Body $body -SkipCertificateCheck
}
