#!/bin/bash -e
# Author: William Lam
# Website: williamlam.com
# Description: Retrieve Objects/Metrics Stats from VCF Operations 9.0

$VCF_OPERATIONS_HOSTNAME="vcf01.vcf.lab"
$VCF_OPERATIONS_USERNAME="admin"
$VCF_OPERATIONS_PASSWORD='VMware1!VMware1!'


$payload = @{
    "username" = $VCF_OPERATIONS_USERNAME
    "password" = $VCF_OPERATIONS_PASSWORD
    "authSource" = "local"
}

$body = $payload | ConvertTo-Json

$requests = Invoke-WebRequest -Uri "https://${VCF_OPERATIONS_HOSTNAME}/suite-api/api/auth/token/acquire" -Method POST -Headers @{"Content-Type" = "application/json";"Accept" = "application/json"} -Body $body -SkipCertificateCheck

$VCF_OPERATIONS_AUTH_TOKEN=$(($requests.Content | ConvertFrom-Json).token)

$headers = @{
    "Content-Type" = "application/json"
    "Accept" = "application/json"
    "Authorization" = "OpsToken ${VCF_OPERATIONS_AUTH_TOKEN}"
}

$requests = Invoke-WebRequest -Uri "https://${VCF_OPERATIONS_HOSTNAME}/suite-api/api/adapters" -Method GET -Headers $headers -SkipCertificateCheck

$adapterResults = ($requests.content | ConvertFrom-Json).adapterInstancesInfoDto

$results = @()
foreach($adapterResult in $adapterResults) {
    if($adapterResult.numberOfResourcesCollected -eq $null) {
        $objectCount = 0
    } else {
        $objectCount = $adapterResult.numberOfResourcesCollected
    }

    if($adapterResult.numberOfMetricsCollected -eq $null) {
        $metricCount = 0
    } else {
        $metricCount = $adapterResult.numberOfMetricsCollected
    }

    $tmp = [pscustomobject][ordered]@{
        Adapter = $adapterResult.resourceKey.name
        Objects = $objectCount
        Metrics = $metricCount
    }
    $results+=$tmp
}

$results | Sort-Object -Property Adapter | FT

Write-Host "Total Number of Objects: $(($results.Objects | Measure-Object -Sum).Sum)"

Write-Host "Total Number of Metrics: $(($results.Metrics | Measure-Object -Sum).Sum)"

Write-Host

