# Author: William Lam
# Blog: www.virtuallyghetto.com
# Description: Script demonstrating vSphere MOB Automation using PowerShell
# Reference: http://www.virtuallyghetto.com/2016/07/how-to-automate-vsphere-mob-operations-using-powershell.html

$vc_server = "192.168.1.51"
$vc_username = "administrator@vghetto.local"
$vc_password = "VMware1!"
$mob_url = "https://$vc_server/mob/?moid=VpxSettings&method=queryView"

$secpasswd = ConvertTo-SecureString $vc_password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($vc_username, $secpasswd)

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
    $results
    Write-host "Failed to login to vSphere MOB"
    exit 1
}

# The POST data payload must include the vmware-session-nonce varaible + URL-encoded
$body = @"
vmware-session-nonce=$sessionnonce&name=VirtualCenter.InstanceName
"@

# Second request using a POST and specifying our session from initial login + body request
$results = Invoke-WebRequest -Uri $mob_url -WebSession $vmware -Method POST -Body $body

# Clean up the results for further processing
# Extract InnerText, split into string array & remove empty lines
$cleanedUpResults = $results.ParsedHtml.body.innertext.split("`n").replace("`"","") | ? {$_.trim() -ne ""}

# Loop through results looking for valuestring which contains the data we want
foreach ($parsedResults in $cleanedUpResults) {
    if($parsedResults -like "valuestring*") {
        $parsedResults.replace("valuestring","")
    }
}
