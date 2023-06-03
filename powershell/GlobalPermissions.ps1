Function New-GlobalPermission {
<#
    .DESCRIPTION Script to add/remove vSphere Global Permission
    .NOTES  Author:  William Lam
    .NOTES  Site:    www.williamlam.com
    .NOTES  Reference: https://williamlam.com/2017/03/automating-vsphere-global-permissions-with-powercli.html
    .PARAMETER vc_server
        vCenter Server Hostname or IP Address
    .PARAMETER vc_username
        VC Username
    .PARAMETER vc_password
        VC Password
    .PARAMETER vc_user
        Name of the user to remove global permission on
    .PARAMETER vc_role_id
        The ID of the vSphere Role (retrieved from Get-VIRole)
    .PARAMETER propagate
        Whether or not to propgate the permission assignment (true/false)
#>
    param(
        [Parameter(Mandatory=$true)][string]$vc_server,
        [Parameter(Mandatory=$true)][String]$vc_username,
        [Parameter(Mandatory=$true)][String]$vc_password,
        [Parameter(Mandatory=$true)][String]$vc_user,
        [Parameter(Mandatory=$true)][String]$vc_role_id,
        [Parameter(Mandatory=$true)][String]$propagate
    )

    $secpasswd = ConvertTo-SecureString $vc_password -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential($vc_username, $secpasswd)

    # vSphere MOB URL to private enableMethods
    $mob_url = "https://$vc_server/invsvc/mob3/?moid=authorizationService&method=AuthorizationService.AddGlobalAccessControlList"

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
        Write-host "Failed to login to vSphere MOB"
        exit 1
    }

    # Escape username
    $vc_user_escaped = [uri]::EscapeUriString($vc_user)

    # The POST data payload must include the vmware-session-nonce variable + URL-encoded
    $body = @"
vmware-session-nonce=$sessionnonce&permissions=%3Cpermissions%3E%0D%0A+++%3Cprincipal%3E%0D%0A++++++%3Cname%3E$vc_user_escaped%3C%2Fname%3E%0D%0A++++++%3Cgroup%3Efalse%3C%2Fgroup%3E%0D%0A+++%3C%2Fprincipal%3E%0D%0A+++%3Croles%3E$vc_role_id%3C%2Froles%3E%0D%0A+++%3Cpropagate%3E$propagate%3C%2Fpropagate%3E%0D%0A%3C%2Fpermissions%3E
"@
    # Second request using a POST and specifying our session from initial login + body request
    Write-Host "Adding Global Permission for $vc_user ..."
    $results = Invoke-WebRequest -Uri $mob_url -WebSession $vmware -Method POST -Body $body

    # Logout out of vSphere MOB
    $mob_logout_url = "https://$vc_server/invsvc/mob3/logout"
    $results = Invoke-WebRequest -Uri $mob_logout_url -WebSession $vmware -Method GET
}

Function Remove-GlobalPermission {
<#
    .DESCRIPTION Script to add/remove vSphere Global Permission
    .NOTES  Author:  William Lam
    .NOTES  Site:    www.williamlam.com
    .NOTES  Reference: http://www.williamlam.com/2017/02/automating-vsphere-global-permissions-with-powercli.html
    .PARAMETER vc_server
        vCenter Server Hostname or IP Address
    .PARAMETER vc_username
        VC Username
    .PARAMETER vc_password
        VC Password
    .PARAMETER vc_user
        Name of the user to remove global permission on
    .EXAMPLE
        PS> Remove-GlobalPermission -vc_server "192.168.1.51" -vc_username "administrator@vsphere.local" -vc_password "VMware1!" -vc_user "VGHETTO\lamw"
#>
    param(
        [Parameter(Mandatory=$true)][string]$vc_server,
        [Parameter(Mandatory=$true)][String]$vc_username,
        [Parameter(Mandatory=$true)][String]$vc_password,
        [Parameter(Mandatory=$true)][String]$vc_user
    )

    $secpasswd = ConvertTo-SecureString $vc_password -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential($vc_username, $secpasswd)

    # vSphere MOB URL to private enableMethods
    $mob_url = "https://$vc_server/invsvc/mob3/?moid=authorizationService&method=AuthorizationService.RemoveGlobalAccess"

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
        Write-host "Failed to login to vSphere MOB"
        exit 1
    }

    # Escape username
    $vc_user_escaped = [uri]::EscapeUriString($vc_user)

    # The POST data payload must include the vmware-session-nonce variable + URL-encoded
    $body = @"
vmware-session-nonce=$sessionnonce&principals=%3Cprincipals%3E%0D%0A+++%3Cname%3E$vc_user_escaped%3C%2Fname%3E%0D%0A+++%3Cgroup%3Efalse%3C%2Fgroup%3E%0D%0A%3C%2Fprincipals%3E
"@
    # Second request using a POST and specifying our session from initial login + body request
    Write-Host "Removing Global Permission for $vc_user ..."
    $results = Invoke-WebRequest -Uri $mob_url -WebSession $vmware -Method POST -Body $body

    # Logout out of vSphere MOB
    $mob_logout_url = "https://$vc_server/invsvc/mob3/logout"
    $results = Invoke-WebRequest -Uri $mob_logout_url -WebSession $vmware -Method GET
}

### Sample Usage of Enable/Disable functions ###

$vc_server = "192.168.1.51"
$vc_username = "administrator@vsphere.local"
$vc_password = "VMware1!"
$vc_role_id = "-1"
$vc_user = "VGHETTO\lamw"
$propagate = "true"

# Connect to vCenter Server
$server = Connect-VIServer -Server $vc_server -User $vc_username -Password $vc_password

#New-GlobalPermission -vc_server $vc_server -vc_username $vc_username -vc_password $vc_password -vc_user $vc_user -vc_role_id $vc_role_id -propagate $propagate

#Remove-GlobalPermission -vc_server $vc_server -vc_username $vc_username -vc_password $vc_password -vc_user $vc_user

# Disconnect from vCenter Server
Disconnect-viserver $server -confirm:$false
