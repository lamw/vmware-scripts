$VCF_OPERATIONS_HOSTNAME="vcf01.vcf.lab"
$VCF_OPERATIONS_USERNAME="admin"
$VCF_OPERATIONS_PASSWORD='VMware1!VMware1!'
$PURGE_VIDB_SSO_CONFIGURATION_IDS=$()

$body = @{
    "username" = $VCF_OPERATIONS_USERNAME
    "password" = $VCF_OPERATIONS_PASSWORD
    "authSource" = "local"
} | ConvertTo-Json

Write-Host -ForegroundColor Cyan "Acquiring VCF Operations access token ..."
$requests = Invoke-WebRequest -Uri "https://${VCF_OPERATIONS_HOSTNAME}/suite-api/api/auth/token/acquire" -Method POST -Headers @{"Content-Type" = "application/json";"Accept" = "application/json"} -Body $body -SkipCertificateCheck

$VCF_OPERATIONS_AUTH_TOKEN=$(($requests.Content | ConvertFrom-Json).token)

$headers = @{
    "Content-Type" = "application/json"
    "Accept" = "application/json"
    "Authorization" = "OpsToken ${VCF_OPERATIONS_AUTH_TOKEN}"
    "X-Ops-API-use-unsupported" = "true"
}

Write-Host -ForegroundColor Cyan "Retrieving all VMware Identity Brokers ..."
$requests = Invoke-WebRequest -Uri "https://${VCF_OPERATIONS_HOSTNAME}/suite-api/api/fleet-management/iam/vidbs" -Method GET -Headers $headers -SkipCertificateCheck

$vidbs = ($requests.content | ConvertFrom-Json).vidbs

$results = @()
foreach($vidb in $vidbs) {
    $tmp = [pscustomobject] [ordered]@{
        id = $vidb.id
        fqdn = $vidb.fqdn
        displayName = $vidb.displayName
        deploymentType = $vidb.deploymentType
        eligibilityStatus = $vidb.vidbStatus.eligibilityStatus
        eligibilityReason = $vidb.vidbStatus.reasons
        healthy = $vidb.healthy
        version = $vidb.version
        vcfInstanceId = $vidb.vcfInstanceId
        oidcConfigurationUrl = $vidb.oidcConfigurationUrl
    }
    $results+=$tmp
}

$results

if($PURGE_VIDB_SSO_CONFIGURATION_IDS.count -gt 0) {
    foreach($vidb in $vidbs) {
        if($PURGE_VIDB_SSO_CONFIGURATION_IDS -contains $vidb.id) {
            Write-Host -ForegroundColor yellow "Purging SSO configuration for VIDB ID: $($vidb.id) $($vidb.fqdn)"
            $requests = Invoke-WebRequest -Uri "https://${VCF_OPERATIONS_HOSTNAME}/suite-api/internal/vidb/identityproviders?purgeSSOConfig=true&vidbResourceId=$(${vidb}.id)&forceDelete=true" -Method DELETE -Headers $headers -SkipCertificateCheck
            Write-Host -ForegroundColor yellow "StatusCode: $($requests.StatusCode)`n"
            ($requests.content | ConvertFrom-Json)
        }
    }
}

Write-Host
