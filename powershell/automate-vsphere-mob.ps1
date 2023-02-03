# Author: William Lam
# Blog: www.williamlam.com
# Description: Script demonstrating vSphere MOB Automation using PowerShell
# Reference: http://www.williamlam.com/2016/07/how-to-automate-vsphere-mob-operations-using-powershell.html

$vc_server = "192.168.1.51"
$vc_username = "administrator@vghetto.local"
$vc_password = "VMware1!"
$mob_url = "https://$vc_server/mob/?moid=VpxSettings&method=queryView"

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

# Logout out of vSphere MOB
$mob_logout_url = "https://$vc_server/mob/logout"
Invoke-WebRequest -Uri $mob_logout_url -WebSession $vmware -Method GET

# Clean up the results for further processing
# Extract InnerText, split into string array & remove empty lines
$cleanedUpResults = $results.ParsedHtml.body.innertext.split("`n").replace("`"","") | ? {$_.trim() -ne ""}

# Loop through results looking for valuestring which contains the data we want
foreach ($parsedResults in $cleanedUpResults) {
    if($parsedResults -like "valuestring*") {
        $parsedResults.replace("valuestring","")
    }
}
