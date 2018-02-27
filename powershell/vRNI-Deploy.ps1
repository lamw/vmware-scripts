<#
.SYNOPSIS Script to deploy vRealize Network Insight (vRNI) 3.2 Platform + Proxy VM
.NOTES  Author:  William Lam
.NOTES  Site:    www.virtuallyghetto.com
.NOTES  Reference: http://www.virtuallyghetto.com/2016/12/automated-deployment-and-setup-of-vrealize-network-insight-vrni.html
#>

# Path to vRNI OVAs
$vRNIPlatformOVA = "C:\Users\primp\Desktop\VMWare-vRealize-Networking-insight-3.2.0.1480511973-platform.ova"
$vRNIProxyOVA = "C:\Users\primp\Desktop\VMWare-vRealize-Networking-insight-3.2.0.1480511973-proxy.ova"

# vRNI License Key
$vRNILicenseKey = ""

# vRNI Platform VM Config
$vRNIPlatformVMName = "vRNI-Platform-3.2"
$vRNIPlatformIPAddress = "172.30.0.199"
$vRNIPlatformNetmask = "255.255.255.0"
$vRNIPlatformGateway = "172.30.0.1"

# vRNI Proxy VM Config
$vRNIProxyVMName = "vRNI-Proxy-3.2"
$vRNIProxyIPAddress = "172.30.0.201"
$vRNIProxyNetmask = "255.255.255.0"
$vRNIProxyGateway = "172.30.0.201"

# vRNI Deployment Settings
$DeploymentSize = "medium"
$DNS = "172.30.0.100"
$DNSDomain = "primp-industries.com"
$NTPServer = "172.30.0.100"

$VMCluster = "Primp-Cluster"
$VMDatastore = "himalaya-local-SATA-re4gp4T:storage"
$VMNetwork = "access333"
$vmhost = "10.197.4.207"

### DO NOT EDIT BEYOND HERE ###

Function My-Logger {
    param(
    [Parameter(Mandatory=$true)]
    [String]$message
    )

    $timeStamp = Get-Date -Format "MM-dd-yyyy_hh-mm-ss"

    Write-Host -NoNewline -ForegroundColor White "[$timestamp]"
    Write-Host -ForegroundColor Green " $message"
}

$StartTime = Get-Date

$hash = @{licenseKey = $vRNILicenseKey}
$json = $hash | ConvertTo-Json

$location = Get-Cluster $VMCluster
$datastore = Get-Datastore -Name $VMDatastore
$network = Get-VirtualPortGroup -Name $VMNetwork -VMHost $vmhost
$vRNIPlatformOVFConfig = Get-OvfConfiguration $vRNIPlatformOVA
$vRNIProxyOVFConfig = Get-OvfConfiguration $vRNIProxyOVA

$vRNIPlatformOVFConfig.DeploymentOption.Value = $DeploymentSize
$vRNIPlatformOVFConfig.NetworkMapping.VM_Network.Value = $VMNetwork
$vRNIPlatformOVFConfig.Common.IP_Address.Value = $vRNIPlatformIPAddress
$vRNIPlatformOVFConfig.Common.Netmask.Value = $vRNIPlatformNetmask
$vRNIPlatformOVFConfig.Common.Default_Gateway.Value = $vRNIPlatformGateway
$vRNIPlatformOVFConfig.Common.DNS.Value = $DNS
$vRNIPlatformOVFConfig.Common.Domain_Search.Value = $DNSDomain
$vRNIPlatformOVFConfig.Common.NTP.Value = $NTPServer

$vRNIProxyOVFConfig.DeploymentOption.Value = $DeploymentSize
$vRNIProxyOVFConfig.NetworkMapping.VM_Network.Value = $VMNetwork
$vRNIProxyOVFConfig.Common.IP_Address.Value = $vRNIProxyIPAddress
$vRNIProxyOVFConfig.Common.Netmask.Value = $vRNIProxyNetmask
$vRNIProxyOVFConfig.Common.Default_Gateway.Value = $vRNIProxyGateway
$vRNIProxyOVFConfig.Common.DNS.Value = $DNS
$vRNIProxyOVFConfig.Common.Domain_Search.Value = $DNSDomain
$vRNIProxyOVFConfig.Common.NTP.Value = $NTPServer

My-Logger "Deploying vRNI Platform OVA ..."
$vRNIPlatformVM = Import-VApp -OvfConfiguration $vRNIPlatformOVFConfig -Source $vRNIPlatformOVA -Name $vRNIPlatformVMName -VMHost $vmhost -Datastore $datastore -DiskStorageFormat thin -Location $location

My-Logger "Starting vRNI Platform VM ..."
Start-VM -VM $vRNIPlatformVM -Confirm:$false | Out-Null

My-Logger "Waiting for 600 seconds for services on platform to come up ..."
sleep 600
My-Logger "Checking to see if vRNI Platform VM is ready ..."
while(1) {
    try {
        $results = Invoke-WebRequest -Uri https://$vRNIPlatformIPAddress/#license/step/1 -Method GET
        if($results.StatusCode -eq 200) {
            break
        }
    }
    catch {
        My-Logger "vRNI Platform is not ready, sleeping for 120 seconds ..."
        sleep 120
    }
}

# vRNI URLs for configuration
$validateURL = "https://$vRNIPlatformIPAddress/api/management/licensing/validate"
$activateURL = "https://$vRNIPlatformIPAddress/api/management/licensing/activate"
$proxySecretGenURL = "https://$vRNIPlatformIPAddress/api/management/nodes"

My-Logger "Verifying vRNI License Key ..."
$results = Invoke-WebRequest -Uri $validateURL -SessionVariable vmware -Method POST -ContentType "application/json" -Body $json
if($results.StatusCode -eq 200) {
    My-Logger "Activating vRNI License Key ..."
    $results = Invoke-WebRequest -Uri $activateURL -WebSession $vmware -Method POST -ContentType "application/json" -Body $json
    if($results.StatusCode -eq 200) {
        My-Logger "Generating vRNI Proxy Shared Secret ..."
        $results = Invoke-WebRequest -Uri $proxySecretGenURL -WebSession $vmware -Method POST -ContentType "application/json"
        if($results.StatusCode -eq 200) {
            $cleanedUpResults = $results.ParsedHtml.body.innertext.split("`n").replace("`"","") | ? {$_.trim() -ne ""}
            $lString = $cleanedUpResults.replace("{status:true,statusCode:{code:0,codeStr:OK},message:Proxy Key Generated,data:","")
            $vRNIPlatformSharedSecret = $lString.replace("}","")

            if($vRNIPlatformSharedSecret -ne $null) {
                # Update OVF Property w/shared secret
                $vRNIProxyOVFConfig.Common.Proxy_Shared_Secret.Value = $vRNIPlatformSharedSecret

                My-Logger "Deploying vRNI Proxy OVA w/Platform shared secret  ..."
                $vRNIProxyVM = Import-VApp -OvfConfiguration $vRNIProxyOVFConfig -Source $vRNIProxyOVA -Name $vRNIProxyVMName -VMHost $vmhost -Datastore $datastore -DiskStorageFormat thin -Location $location

                My-Logger "Starting vRNI Proxy VM ..."
                Start-VM -VM $vRNIProxyVM -Confirm:$false | Out-Null

                My-Logger "Waiting for vRNI Proxy VM to be detected by vRNI Platform VM ..."
                $notDectected = $true
                while($notDectected) {
                    $results = Invoke-WebRequest -Uri $proxySecretGenURL -WebSession $vmware -Method GET -ContentType "application/json"
                    $nodes = $results.Content | ConvertFrom-Json
                    if($nodes.Count -eq 2) {
                        foreach ($node in $nodes) {
                            if($node.ipAddress -eq "$vRNIProxyIPAddress" -and $node.healthStatus -eq "HEALTHY") {
                                My-Logger "vRNI Proxy VM detected"
                                $notDectected = $false
                            }
                        }
                    } else {
                        sleep 60
                        My-Logger "Still waiting for vRNI Proxy VM, sleeping for 60 seconds ..."
                    }
                }
            } else {
                Write-Host -ForegroundColor Red "Failed to retrieve vRNI Platform Shared Secret Key ..."
                break
            }
        }
    } else {
        Write-Host -ForegroundColor Red "Failed to activate vRNI License Key ..."
        break
    }
} else {
    Write-Host -ForegroundColor Red "Failed to validate vRNI License Key ... "
}

$EndTime = Get-Date
$duration = [math]::Round((New-TimeSpan -Start $StartTime -End $EndTime).TotalMinutes,2)

My-Logger "vRealize Network Insight Deployment Complete!"
My-Logger "         Login to https://$vRNIPlatformIPAddress using"
My-Logger "            Username: admin@local"
My-Logger "            Password: admin"
My-Logger "StartTime: $StartTime"
My-Logger "  EndTime: $EndTime"
My-Logger " Duration: $duration minutes"
