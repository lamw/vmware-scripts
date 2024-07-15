# Author: William Lam
# Blog: https://williamlam.com
# Description: Retreiving vCenter Server VM MAC Address Blocklist using vSphere MOB via PowerShell
# Reference: https://williamlam.com/2024/07/automating-the-retrieval-reclamation-of-vm-mac-address-blocklist-for-vcenter-server-using-the-vsphere-mob.html

$vc_server = "vcsa.primp-industries.local"
$vc_username = "administrator@vsphere.local"
$vc_password = "FILL_ME_IN"

## DO NOT EDIT BEYOND HERE ##

$mob_url = "https://$vc_server/mob?moid=networkManager&method=fetchRelocatedMACAddress"

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
vmware-session-nonce=${sessionnonce}
"@

# Second request using a POST and specifying our session from initial login + body request
$results = Invoke-WebRequest -Uri $mob_url -WebSession $vmware -Method POST -Body $body -SkipCertificateCheck

if($results.StatusCode -eq 200) {
    $htmlString = $results.RawContent

    $matches = [regex]::Matches($htmlString, 'td class="clean">&quot;([0-9A-Fa-f:]+)&quot;</td>')

    $macAddresses = $matches | ForEach-Object { $_.Groups[1].Value }

    if($macAddresses.count -eq 0) {
        Write-Host -ForegroundColor Cyan "vCenter Server VM MAC Address Block List is empty ..."
    } else {
        Write-Host -ForegroundColor Cyan "vCenter Server VM MAC Address Block List ..."
        $macAddresses
    }
}

# Logout out of vSphere MOB
$mob_logout_url = "https://$vc_server/mob/logout"
Write-Host -ForegroundColor Green "Logging out of the vSphere MOB ...`n"
$results = Invoke-WebRequest -Uri $mob_logout_url -WebSession $vmware -Method GET -SkipHttpErrorCheck -SkipCertificateCheck
