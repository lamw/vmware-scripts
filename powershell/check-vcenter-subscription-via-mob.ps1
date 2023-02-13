# Author: William Lam
# Blog: www.williamlam.com
# Description: Check vCenter Server subscription information using Lookup Service MOB via PowerShell
# Reference: https://williamlam.com/2023/how-to-check-if-your-vcenter-server-is-using-vsphere-vsan-subscription.html

$vc_server = "vcsa.primp-industries.local"
$vc_username = "administrator@vsphere.local"
$vc_password = "VMware1!"

## DO NOT EDIT BEYOND HERE ##

$mob_url = "https://$vc_server/ls/mob?moid=cis.license.management.SystemManagementService&method=SearchProductUtilizations"

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
    Write-host "Failed to login to vSphere MOB"
    exit 1
}

# The POST data payload must include the vmware-session-nonce varaible + URL-encoded
$body = @"
vmware-session-nonce=${sessionnonce}&productSearchSpec=%3CproductSearchSpec+xmlns%3Axsi%3D%22http%3A%2F%2Fwww.w3.org%2F2001%2FXMLSchema-instance%22+xsi%3Atype%3D%22CisLicenseManagementProductSearchSpecByIds%22%3E%0D%0A%3CproductIds%3EVMware+VirtualCenter+Servervc.vsphere.cloud.subscription%3C%2FproductIds%3E%0D%0A%3C%2FproductSearchSpec%3E
"@

# Second request using a POST and specifying our session from initial login + body request
$results = Invoke-WebRequest -Uri $mob_url -WebSession $vmware -Method POST -Body $body

if($results.StatusCode -eq 200) {
    if($results.Content -match "CisLicenseFaultNotFoundFault") {
        Write-Host -ForegroundColor Yellow "This vCenter Server has NOT been converted to subscription ..."
    } else {
        Write-Host -ForegroundColor green "This vCenter Server has been converted to subscription ..."
    }
} else {
    Write-Error "Failed to query vCenter Server for subscription information ..."
}

# Logout out of Lookup Service MOB
$mob_logout_url = "https://$vc_server/ls/mob/logout"
Write-Host -ForegroundColor Green "Logging out of the Lookup Service MOB ..."
$results = Invoke-WebRequest -Uri $mob_logout_url -WebSession $vmware -Method GET -SkipHttpErrorCheck
