# Author: William Lam
# Blog: www.virtuallyghetto.com
# Description: Script to disable/enable vMotion capability for a specific VM
# Reference: http://www.virtuallyghetto.com/2016/07/how-to-easily-disable-vmotion-for-a-particular-virtual-machine.thml

Function Enable-vSphereMethod {
    param(
    [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    [String]$vmmoref,
    [string]$vc_server,
    [String]$vc_username,
    [String]$vc_password,
    [String]$enable_method
    )

    $secpasswd = ConvertTo-SecureString $vc_password -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential($vc_username, $secpasswd)

    # vSphere MOB URL to private enableMethods
    $mob_url = "https://$vc_server/mob/?moid=AuthorizationManager&method=enableMethods"

# Ingore SSL Warnings
add-type -TypeDefinition  @"
        using System.Net;
        using System.Security.Cryptography.X509Certificates;
        public class TrustAllCertsPolicy : ICertificatePolicy {
            public bool CheckValidationResult(
                ServicePoint srvPoint, X509Certificate certificate,
                WebRequest request, int certificateProblem) {
                return true;
            }
        }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

    # Initial login to vSphere MOB using GET and store session using $vmware variable
    $results = Invoke-WebRequest -Uri $mob_url -SessionVariable vmware -Credential $credential -Method GET

    # Extract hidden vmware-session-nonce which must be included in future requests to prevent CSRF error
    # Credit to https://blog.netnerds.net/2013/07/use-powershell-to-keep-a-cookiejar-and-post-to-a-web-form/ for parsing vmware-session-nonce via Powershell
    if($results.StatusCode -eq 200) {
        $null = $results -match 'name="vmware-session-nonce" type="hidden" value="?([^\s^"]+)"'
        $sessionnonce = $matches[1]
    } else {
        Write-host "Failed to login to vSphere MOB"
        exit 1
    }

    # The POST data payload must include the vmware-session-nonce variable + URL-encoded
    $body = @"
vmware-session-nonce=$sessionnonce&entity=%3Centity+type%3D%22ManagedEntity%22+xsi%3Atype%3D%22ManagedObjectReference%22%3E$vmmoref%3C%2Fentity%3E%0D%0A&method=%3Cmethod%3E$enable_method%3C%2Fmethod%3E
"@

    # Second request using a POST and specifying our session from initial login + body request
    $results = Invoke-WebRequest -Uri $mob_url -WebSession $vmware -Method POST -Body $body
}

Function Disable-vSphereMethod {
    param(
    [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    [String]$vmmoref,
    [string]$vc_server,
    [String]$vc_username,
    [String]$vc_password,
    [String]$disable_method
    )

    $secpasswd = ConvertTo-SecureString $vc_password -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential($vc_username, $secpasswd)

    # vSphere MOB URL to private disableMethods
    $mob_url = "https://$vc_server/mob/?moid=AuthorizationManager&method=disableMethods"

# Ingore SSL Warnings
add-type -TypeDefinition  @"
        using System.Net;
        using System.Security.Cryptography.X509Certificates;
        public class TrustAllCertsPolicy : ICertificatePolicy {
            public bool CheckValidationResult(
                ServicePoint srvPoint, X509Certificate certificate,
                WebRequest request, int certificateProblem) {
                return true;
            }
        }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

    # Initial login to vSphere MOB using GET and store session using $vmware variable
    $results = Invoke-WebRequest -Uri $mob_url -SessionVariable vmware -Credential $credential -Method GET

    # Extract hidden vmware-session-nonce which must be included in future requests to prevent CSRF error
    # Credit to https://blog.netnerds.net/2013/07/use-powershell-to-keep-a-cookiejar-and-post-to-a-web-form/ for parsing vmware-session-nonce via Powershell
    if($results.StatusCode -eq 200) {
        $null = $results -match 'name="vmware-session-nonce" type="hidden" value="?([^\s^"]+)"'
        $sessionnonce = $matches[1]
    } else {
        Write-host "Failed to login to vSphere MOB"
        exit 1
    }

    # The POST data payload must include the vmware-session-nonce variable + URL-encoded
    $body = @"
vmware-session-nonce=$sessionnonce&entity=%3Centity+type%3D%22ManagedEntity%22+xsi%3Atype%3D%22ManagedObjectReference%22%3E$vmmoref%3C%2Fentity%3E%0D%0A%0D%0A&method=%3CDisabledMethodRequest%3E%0D%0A+++%3Cmethod%3E$disable_method%3C%2Fmethod%3E%0D%0A%3C%2FDisabledMethodRequest%3E%0D%0A%0D%0A&sourceId=self
"@

    # Second request using a POST and specifying our session from initial login + body request
    $results = Invoke-WebRequest -Uri $mob_url -WebSession $vmware -Method POST -Body $body
}

### Sample Usage of Enable/Disable functions ###

$vc_server = "192.168.1.51"
$vc_username = "administrator@vghetto.local"
$vc_password = "VMware1!"
$vm_name = "TestVM-1"
$method_name = "MigrateVM_Task"

# Connect to vCenter Server
$server = Connect-VIServer -Server $vc_server -User $vc_username -Password $vc_password

$vm = Get-VM -Name $vm_name
$vm_moref = (Get-View $vm).MoRef.Value

#Disable-vSphereMethod -vc_server $vc_server -vc_username $vc_username -vc_password $vc_password -vmmoref $vm_moref -disable_method $method_name

#Enable-vSphereMethod -vc_server $vc_server -vc_username $vc_username -vc_password $vc_password -vmmoref $vm_moref -enable_method $method_name

# Disconnect from vCenter Server
Disconnect-viserver $server -confirm:$false
