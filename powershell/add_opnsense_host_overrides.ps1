$opnsense_uri = "https://FILL_ME_IN"
$key = 'FILL_ME_IN'
$secret = 'FILL_ME_IN'
$csv_input = "dns.csv"

### DO NOT EDIT BEYOND HERE ###

$csv = Import-Csv $csv_input

$addHostOverrideURL = "${opnsense_uri}/api/unbound/settings/AddHostOverride"

$encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("$($key):$($secret)"))
$basicAuthValue = "Basic $encodedCreds"

$headers = @{
    "Content-Type" = "application/json"
    "Authorization" = $basicAuthValue
}

foreach ($item in $csv) {
    $hostname,$domain = $item.FQDN -split "\.", 2

    $payload = @{
        "host" = [ordered]@{
            "enabled" = "1"
            "hostname" = $hostname
            "domain" = $domain
            "rr" = "A"
            "mxprio" = ""
            "mx" = ""
            "server" = $item.IP
            "description" = $item.DESCRIPTION
        }
    }

    $body = $payload | ConvertTo-Json

    $results = Invoke-WebRequest -Uri $addHostOverrideURL -Method POST -Headers $headers -body $body -SkipCertificateCheck
    if($results.StatusCode) {
        Write-Host -ForegroundColor Cyan "Successfully added ${hostname}.${domain} ($(${item}.IP) ..."
    } else {
        $results
    }
}