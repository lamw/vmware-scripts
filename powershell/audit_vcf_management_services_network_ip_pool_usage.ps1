# VCF Management Services (VCFMS) Credentials
$VCFManagementServicesPassword = "VMware1!VMware1!"
$VCFManagementServicesRuntimeFQDN = "vcf-msr02.vcf.lab"

### DO NOT EDIT BEYOND HERE ###

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

# --- Retrieve VCF Fleet FQDN
$connectivityParams = @{
    Uri                  = "https://${VCFManagementServicesRuntimeFQDN}/api/v1/components?type=vsp"
    Method               = 'GET'
    Headers              = @{
        'Content-Type'  = 'application/json'
        'Authorization' = "Bearer ${accessToken}"
    }
    SkipCertificateCheck = $true
}

$request = Invoke-WebRequest @connectivityParams
$VCFManagementServicesFleetFQDN = ($request.Content | ConvertFrom-Json).components.spec.configuration.ingress.fleet.fqdn

# --- Retrieve VCF Management Services Component
$connectivityParams = @{
    Uri                  = "https://${VCFManagementServicesFleetFQDN}/fleet-lcm/v1/components"
    Method               = 'GET'
    Headers              = @{
        'Content-Type'  = 'application/json'
        'Authorization' = "Bearer ${accessToken}"
    }
    SkipCertificateCheck = $true
}

$request = Invoke-WebRequest @connectivityParams
$components = ($request.Content | ConvertFrom-Json).components

$vcfmss = ($components | where {$_.componentType -eq "VSP"})

# --- Retrieve VCFMS Component Config
$results = @()
foreach($vcfms in $vcfmss) {
    $connectivityParams = @{
        Uri                  = "https://${VCFManagementServicesFleetFQDN}/fleet-lcm/v1/components/$(${vcfms}.id)/config"
        Method               = 'GET'
        Headers              = @{
            'Content-Type'  = 'application/json'
            'Authorization' = "Bearer ${accessToken}"
        }
        Body                = $body
        SkipCertificateCheck = $true
    }

    $request = Invoke-WebRequest @connectivityParams
    $vcfms_config = ($request.Content | ConvertFrom-Json)

    $nodes = $vcfms.nodes
    $workerCount = 0
    $controlCount = 0
    $controlIps = @()
    $workerIps = @()
    $seenIps = @()
    foreach($node in $nodes) {
        if($node.nodeType -eq "worker") {
            $workerCount+=1
            $workerIps+=$node.ipAddress
            $seenIps+=$node.ipAddress
        }

        if($node.nodeType -eq "control-plane") {
            $controlCount+=1
            $controlIps+="$($node.ipAddress) ($($node.name))"
            $seenIps+=$node.ipAddress
        }
    }

    function ConvertTo-IpList {
        param(
            [string[]]$Ranges
        )

        $ipList = @()

        foreach($range in $Ranges) {
            if([string]::IsNullOrWhiteSpace($range)) {
                continue
            }

            if($range -match '^(?<start>(?:\d{1,3}\.){3}\d{1,3})-(?<end>(?:\d{1,3}\.){3}\d{1,3})$') {
                $startBytes = [System.Net.IPAddress]::Parse($Matches.start).GetAddressBytes()
                $endBytes = [System.Net.IPAddress]::Parse($Matches.end).GetAddressBytes()

                [Array]::Reverse($startBytes)
                [Array]::Reverse($endBytes)

                $startIp = [BitConverter]::ToUInt32($startBytes, 0)
                $endIp = [BitConverter]::ToUInt32($endBytes, 0)

                for($currentIp = $startIp; $currentIp -le $endIp; $currentIp++) {
                    $currentBytes = [BitConverter]::GetBytes($currentIp)
                    [Array]::Reverse($currentBytes)
                    $ipList += ([System.Net.IPAddress]::new($currentBytes)).ToString()
                }
            }
            else {
                $ipList += $range
            }
        }

        return $ipList
    }

    $poolIps = ConvertTo-IpList -Ranges $vcfms_config.ipv4Pool
    $unusedIps = @()
    foreach($poolIp in $poolIps) {
        if($seenIps -notcontains $poolIp) {
            $unusedIps += $poolIp
        }
    }

    $tmp = [PSCustomObject] [ordered]@{
        Id = $vcfms.Id
        Fqdn = $vcfms.fqdn
        Size = $vcfms.size
        Version = $vcfms.version
        ControlPlane = $controlIps | Out-String
        ControlPlaneCount = $controlCount
        WorkerCount = $workerCount
        IpPool = $vcfms_config.ipv4Pool  | Out-String
        IpPoolTotalIps = $poolIps.count
        IpPoolIpUsed = ($workerIps).count + ($controlIps).count
        IpPoolIpFree = $unusedIps.Count
        IpPoolUsed = if($poolIps.Count -gt 0) { "$([math]::Floor(((($workerIps).count + ($controlIps).count) / $poolIps.Count) * 100))%" } else { "0%" }
        IpPoolUsedIps = $seenIps | Out-String
        IpPoolFreeIps = $unusedIps | Out-String
    }

    $results+=$tmp
}

$results
