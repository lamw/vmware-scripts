# Author: William Lam
# Description: Initial Configuration for VCF Operations 9.x

$VCF_OPERATIONS_FQDN="vcf02.vcf.lab"
$VCF_OPERATIONS_IP="172.30.0.100"
$VCF_OPERATIONS_ADMIN_PASSWORD='VMware1!VMware1!'
$VCF_OPERATIONS_NTP_SERVERS = @("0.pool.ntp.org", "1.pool.ntp.org")

#### DO NOT EDIT BEYOND HERE ####

$headers = @{
    "Content-Type" = "application/json"
    "Accept" = "application/json"
}

# Retrieve VCF Operations Thumbprint
$thumbprint = (Invoke-WebRequest -Uri "https://${VCF_OPERATIONS_FQDN}/casa/node/thumbprint" -Headers $headers -Method GET -SkipCertificateCheck).Content

$config = [ordered]@{
    "master" = @{
        "name" = "master"
        "address" = $VCF_OPERATIONS_IP
        "thumbprint" = $thumbprint
    }
    "admin_password" = $VCF_OPERATIONS_ADMIN_PASSWORD
    "ntp_servers" = $VCF_OPERATIONS_NTP_SERVERS
    "init" = $true
    "dry-run" = $false
}

$body = $config | ConvertTo-Json

$response = Invoke-WebRequest -Uri "https://${VCF_OPERATIONS_FQDN}/casa/cluster" -Headers $headers -Method Post -SkipCertificateCheck -Body $body
if ($response.StatusCode -eq 202) {
    Write-Host -ForegroundColor Yellow "Starting initial VCF Operations configuration ..."

    $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("admin:$($VCF_OPERATIONS_ADMIN_PASSWORD)"))
    $basicAuthValue = "Basic $encodedCreds"
    $headers.Add("Authorization", $basicAuthValue)

    $timeoutSeconds = 1800      # 30 minutes
    $sleepInterval  = 300       # 5 minutes
    $deadline       = (Get-Date).AddSeconds($timeoutSeconds)

    do {
        try {
            $response = Invoke-WebRequest `
                -Uri "https://${VCF_OPERATIONS_FQDN}/casa/cluster/status" `
                -Headers $headers `
                -Method Get `
                -SkipCertificateCheck `
                -TimeoutSec 10

            if ($response.StatusCode -eq 200) {
                $clusterState = ($response.Content | ConvertFrom-Json).cluster_state
                Write-Host -ForegroundColor Cyan "Current VCF Operations Cluster State: $clusterState"

                if ($clusterState -eq "INITIALIZED") {
                    Write-Host -ForegroundColor Green "VCF Operations configuration has completed."
                    return
                }
            }
            else {
                Write-Warning "HTTP status: $($response.StatusCode)"
            }
        }
        catch {
            Write-Warning "Endpoint not reachable: $($_.Exception.Message)"
        }

        if ((Get-Date) -ge $deadline) {
            throw "Timeout after 30 minutes waiting for VCF Operations to reach INITIALIZED state."
        }

        Write-Host "Sleeping $sleepInterval seconds..."
        Start-Sleep -Seconds $sleepInterval

    } while ($true)

} else {
    Write-Error "Unable to start initial VCF Operations configuration"
}
