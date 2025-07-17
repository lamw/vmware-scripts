$sddcmFQDN = "sddcm01.vcf.lab"
$sddcmUsername = "administrator@vsphere.local"
$sddcmPassword = "VMware1!VMware1!"

$aviVersion = "31.1.1-24544104"
$aviClusterName = "nsx-alb"
$aviFormFactor = "SMALL"
$aviAdminPassword = "VMware1!VMware1!"
$aviFQDN = "lb01.vcf.lab"
$aviNodeIP = "172.30.0.51"

### DO NOT EDIT BEYOND HERE ###

$payload = @{
    "username" = $sddcmUsername
    "password" = $sddcmPassword
}

$body = $payload | ConvertTo-Json

Write-Host -ForegroundColor Cyan "`nLogging into SDDC Manager ..."
$requests = Invoke-WebRequest -Uri "https://${sddcmFQDN}/v1/tokens" -Method POST -Headers @{"Content-Type"="application/json"} -Body $body -SkipCertificateCheck -TimeoutSec 5
if($requests.StatusCode -eq 200) {
    $accessToken = ($requests.Content | ConvertFrom-Json).accessToken
} else {
    Write-Error "Failed to login to SDDC Manager, please verify credentials are correct"
}

$headers = @{
    "Content-Type" = "application/json"
    "Authorization" = "Bearer ${accessToken}"
}

Write-Host -ForegroundColor Cyan "Retrieving information about VCF Management Domain ..."
$requests = Invoke-WebRequest -Uri "https://${sddcmFQDN}/v1/domains?type=MANAGEMENT" -Method GET -Headers $headers -SkipCertificateCheck -TimeoutSec 5
if($requests.StatusCode -eq 200) {
    $nsxClusterId = ($requests.Content | ConvertFrom-Json).elements.nsxtCluster.id
} else {
    Write-Error "Failed to retrieve VCF Management Domain information"
}

Write-Host -ForegroundColor Cyan "Retrieving NSX ALB Bundle ID  ..."
$requests = Invoke-WebRequest -Uri "https://${sddcmFQDN}/v1/product-version-catalogs" -Method GET -Headers $headers -SkipCertificateCheck -TimeoutSec 5
if($requests.StatusCode -eq 200) {
    $aviBundleId = (($requests.Content | ConvertFrom-Json).patches.NSX_ALB | where {$_.productVersion -eq $aviVersion}).artifacts.bundles.id
} else {
    Write-Error "Failed to retrieve VCF Product Version Catalog"
}

$payload = [ordered]@{
    "clusterName" = $aviClusterName
    "formFactor" = $aviFormFactor
    "adminPassword" = $aviAdminPassword
    "clusterFqdn" = $aviFQDN
    "nodes" = @(@{"ipAddress" = $aviNodeIP})
    "nsxIds" = @($nsxClusterId)
    "bundleId" = $aviBundleId
}

$body = $payload | ConvertTo-Json

Write-Host -ForegroundColor Cyan "Initiating deployment of 1-Node NSX-ALB ..."
$requests = Invoke-WebRequest -Uri "https://${sddcmFQDN}/v1/alb-clusters?skipCompatibilityCheck=true" -Method POST -Body $body -Headers $headers -SkipCertificateCheck
if($requests.StatusCode -eq 202) {
    Write-Host -ForegroundColor Green "Deployment started, you can monitor the progress using the SDDC Manager UI`n"
} else {
    Write-Error "Failed to initiate deployment"
}

