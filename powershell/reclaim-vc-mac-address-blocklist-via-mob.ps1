# Author: William Lam
# Blog: https://williamlam.com
# Description: Reclaim vCenter Server VM MAC Address Blocklist using vSphere MOB via PowerShell
# Reference: https://williamlam.com/2024/07/automating-the-retrieval-reclamation-of-vm-mac-address-blocklist-for-vcenter-server-using-the-vsphere-mob.html

$vc_server = "vcsa.primp-industries.local"
$vc_username = "administrator@vsphere.local"
$vc_password = "FILL_ME_IN"
$vc_instanceUuid = "1fc7d658-9438-47da-a6e7-6c106ef10399" # Use PowerCLI and $global:DefaultVIServer.ExtensionData.Content.About.InstanceUuid to retrieve

## DO NOT EDIT BEYOND HERE ##

$mob_url = "https://$vc_server/mob?moid=networkManager&method=reclaimMAC"

$secpasswd = ConvertTo-SecureString $vc_password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($vc_username, $secpasswd)

$Code = @'
using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;

namespace CertificateCapture
{
    public class Utility
    {
        public static Func<HttpRequestMessage,X509Certificate2,X509Chain,SslPolicyErrors,Boolean> ValidationCallback =
            (message, cert, chain, errors) => {
                var newCert = new X509Certificate2(cert);
                var newChain = new X509Chain();
                newChain.Build(newCert);
                CapturedCertificates.Add(new CapturedCertificate(){
                    Certificate =  newCert,
                    CertificateChain = newChain,
                    PolicyErrors = errors,
                    URI = message.RequestUri
                });
                return true;
            };
        public static List<CapturedCertificate> CapturedCertificates = new List<CapturedCertificate>();
    }

    public class CapturedCertificate
    {
        public X509Certificate2 Certificate { get; set; }
        public X509Chain CertificateChain { get; set; }
        public SslPolicyErrors PolicyErrors { get; set; }
        public Uri URI { get; set; }
    }
}
'@
if ($PSEdition -ne 'Core'){
    Add-Type -AssemblyName System.Net.Http
    if (-not ("CertificateCapture" -as [type])) {
        Add-Type $Code -ReferencedAssemblies System.Net.Http
    }
} else {
    if (-not ("CertificateCapture" -as [type])) {
        Add-Type $Code
    }
}

# Create an HttpClientHandler with a custom server certificate validation callback
$handler = New-Object System.Net.Http.HttpClientHandler
$handler.ServerCertificateCustomValidationCallback = [CertificateCapture.Utility]::ValidationCallback

# Create an HttpClient with the handler
$client = [System.Net.Http.HttpClient]::new($handler)

# Send a GET request to the URL
$response = $client.GetAsync($mob_url).Result

# Extract the captured certificate
$capturedCert = [CertificateCapture.Utility]::CapturedCertificates | Select-Object -Last 1

if ($capturedCert) {
    # Get the SHA1 thumbprint of the captured certificate
    $thumbprint = $capturedCert.Certificate.GetCertHashString()
    $formattedThumbprint = ($thumbprint -split '(?<=\G..)(?=.)') -join ':'
} else {
    Write-Error "No certificate captured."
}

# Clean up
$client.Dispose()

# Initial login to vSphere MOB using GET and store session using $vmware variable
Write-Host -ForegroundColor Green "`nLogging into the vSphere MOB ..."
$results = Invoke-WebRequest -Uri $mob_url -SessionVariable vmware -Credential $credential -Method GET -UseBasicParsing -SkipCertificateCheck

# Extract hidden vmware-session-nonce which must be included in future requests to prevent CSRF error
# Credit to https://blog.netnerds.net/2013/07/use-powershell-to-keep-a-cookiejar-and-post-to-a-web-form/ for parsing vmware-session-nonce via Powershell
if($results.StatusCode -eq 200) {
    $null = $results.Content -match 'name="vmware-session-nonce" type="hidden" value="?([^\s^"]+)"'
    $sessionnonce = $matches[1]
} else {
    $results
    Write-host "Failed to login to vSphere MOB"
    exit 1
}

# The POST data payload must include the vmware-session-nonce varaible + URL-encoded
$body = @"
vmware-session-nonce=${sessionnonce}&<locator><instanceUuid>${vc_instanceuuid}</instanceUuid><url>https://${vc_server}</url><credential><username>$vc_username</username><password>$([System.Web.HttpUtility]::UrlEncode($vc_password))</password></credential><sslThumbprint>$($formattedThumbprint.toLower())</sslThumbprint></locator>
"@

# Second request using a POST and specifying our session from initial login + body request
$results = Invoke-WebRequest -Uri $mob_url -WebSession $vmware -Method POST -Body $body -SkipCertificateCheck

if($results.StatusCode -eq 200) {
    Write-Host -ForegroundColor Cyan "Successfully issued reclaimed operation for vCenter Server VM MAC Address blocklist ..."
}

# Logout out of vSphere MOB
$mob_logout_url = "https://$vc_server/mob/logout"
Write-Host -ForegroundColor Green "Logging out of the vSphere MOB ...`n"
$results = Invoke-WebRequest -Uri $mob_logout_url -WebSession $vmware -Method GET -SkipHttpErrorCheck -SkipCertificateCheck
