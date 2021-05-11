# Author: William Lam
# Blog: www.williamlam.com
# Description: Script querying remote ESXi host without adding to vCenter Server
# Reference: http://www.williamlam.com/2016/07/remotely-query-an-esxi-host-without-adding-to-vcenter-server.html

Function Get-RemoteESXi {
    param(
    [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    [String]$hostname,
    [string]$username,
    [String]$password,
    [string]$port = 443
    )

    # Function to retrieve SSL Thumbprint of a host
    # https://gist.github.com/lamw/988e4599c0f88d9fc25c9f2af8b72c92
    Function Get-SSLThumbprint {
        param(
        [Parameter(
            Position=0,
            Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)
        ]
        [Alias('FullName')]
        [String]$URL
        )

    add-type @"
            using System.Net;
            using System.Security.Cryptography.X509Certificates;
                public class IDontCarePolicy : ICertificatePolicy {
                public IDontCarePolicy() {}
                public bool CheckValidationResult(
                    ServicePoint sPoint, X509Certificate cert,
                    WebRequest wRequest, int certProb) {
                    return true;
                }
            }
"@
        [System.Net.ServicePointManager]::CertificatePolicy = new-object IDontCarePolicy

        # Need to connect using simple GET operation for this to work
        Invoke-RestMethod -Uri $URL -Method Get | Out-Null

        $ENDPOINT_REQUEST = [System.Net.Webrequest]::Create("$URL")
        $SSL_THUMBPRINT = $ENDPOINT_REQUEST.ServicePoint.Certificate.GetCertHashString()

        return $SSL_THUMBPRINT -replace '(..(?!$))','$1:'
    }

    # Host Connection Spec
    $spec = New-Object VMware.Vim.HostConnectSpec
    $spec.Force = $False
    $spec.HostName = $hostname
    $spec.UserName = $username
    $spec.Password = $password
    $spec.Port = $port
    # Retrieve the SSL Thumbprint from ESXi host
    $spec.SslThumbprint = Get-SSLThumbprint "https://$hostname"

    # Using first available Datacenter object to query remote ESXi host 
    return (Get-Datacenter)[0].ExtensionData.QueryConnectionInfoViaSpec($spec)
}

# vCenter Server credentials
$vc_server = "192.168.1.51"
$vc_username = "administrator@vghetto.local"
$vc_password = "VMware1!"

# Remote ESXi credentials to connect
$remote_esxi_hostname = "192.168.1.190"
$remote_esxi_username = "root"
$remote_esxi_password = "vmware123"

$server = Connect-VIServer -Server $vc_server -User $vc_username -Password $vc_password

$result = Get-RemoteESXi -hostname $remote_esxi_hostname -username $remote_esxi_username -password $remote_esxi_password

$result

Disconnect-VIServer $server -Confirm:$false
