# Author: William Lam
# Blog: www.williamlam.com
# Description: Automating License Key Addition using Lookup Service MOB via PowerShell
# Reference: https://williamlam.com/2023/02/how-to-automate-adding-a-license-into-vcenter-server-with-custom-label.html

$vc_server = "vcsa.primp-industries.local"
$vc_username = "administrator@vsphere.local"
$vc_password = "VMware1!"
$license_name = "My Custom License Label"
$license_key = "FILL-ME-IN"

## DO NOT EDIT BEYOND HERE ##

$mob_url = "https://$vc_server/ls/mob?moid=cis.license.management.SystemManagementService&method=AddLicenses"

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

# Initial login to Lookup Service MOB using GET and store session using $vmware variable
Write-Host -ForegroundColor Green "Logging into the Lookup Service MOB ..."
$results = Invoke-WebRequest -Uri $mob_url -SessionVariable vmware -Credential $credential -Method GET -UseBasicParsing

# Extract hidden vmware-session-nonce which must be included in future requests to prevent CSRF error
# Credit to https://blog.netnerds.net/2013/07/use-powershell-to-keep-a-cookiejar-and-post-to-a-web-form/ for parsing vmware-session-nonce via Powershell
if($results.StatusCode -eq 200) {
    $null = $results.Content -match 'name="vmware-session-nonce" type="hidden" value="?([^\s^"]+)"'
    $sessionnonce = $matches[1]
} else {
    $results
    Write-host "Failed to login to Lookup Service MOB"
    exit 1
}

$encoded_license_name = [System.Web.HttpUtility]::UrlEncode($license_name)

# The POST data payload must include the vmware-session-nonce varaible + URL-encoded
$body = @"
vmware-session-nonce=${sessionnonce}&licenseAddSpecs=%3ClicenseAddSpecs+xmlns%3Axsi%3D%22http%3A%2F%2Fwww.w3.org%2F2001%2FXMLSchema-instance%22+xsi%3Atype%3D%22CisLicenseManagementSerialKeyLicenseAddSpec%22%3E%0D%0A++++%3Cname%3E${encoded_license_name}%3C%2Fname%3E%0D%0A++++%3CserialKeys%3E${license_key}%3C%2FserialKeys%3E%0D%0A%3C%2FlicenseAddSpecs%3E
"@

# Second request using a POST and specifying our session from initial login + body request
$results = Invoke-WebRequest -Uri $mob_url -WebSession $vmware -Method POST -Body $body

if($results.StatusCode -eq 200) {
    Write-Host -ForegroundColor green "Successfully added new License key named `"${license_name}`" ..."
} else {
    Write-Error "Failed to add new vCenter License key named `"${license_name}`" ..."
}

# Logout out of Lookup Service MOB
$mob_logout_url = "https://$vc_server/ls/mob/logout"
Write-Host -ForegroundColor Green "Logging out of the Lookup Service MOB ..."
$results = Invoke-WebRequest -Uri $mob_logout_url -WebSession $vmware -Method GET -SkipHttpErrorCheck
