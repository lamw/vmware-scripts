Function Get-VMCreationDate {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.virtuallyghetto.com
     Twitter:       @lamw
    ===========================================================================
    .DESCRIPTION
        This function extract VM Creation Date using vSphere API (currently only available on VMware Cloud on AWS SDDCs)
        which it does by processing the HTML results found in the vSphere MOB. Once this functionality is available
        via the vSphere SDKs, this will be a simple 1-liner for PowerCLI and other vSphere SDKs
    .PARAMETER VMName
        The name of a VM to extract the creation date
    .PARAMETER vc_server
        The name of the VMWonAWS vCenter Server
    .PARAMETER vc_username
        The username of the VMWonAWS vCenter Server
    .PARAMETER VMName
        The password of the VMWonAWS vCenter Server
    .EXAMPLE
        Connect-VIServer -Server $vc_server -User $vc_username -Password $vc_password
        Get-VMCreationDate -vc_server $vc_server -vc_username $vc_username -vc_password $vc_password -vmname $vmname
#>
    param(
    [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    [String]$vmname,
    [string]$vc_server,
    [String]$vc_username,
    [String]$vc_password
    )

    $vm = Get-VM -Name $vmname
    $vm_moref = (Get-View $vm).MoRef.Value
    $vm_moref = $vm_moref -replace "-","%2d"

    $secpasswd = ConvertTo-SecureString $vc_password -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential($vc_username, $secpasswd)

    # vSphere MOB URL to private enableMethods
    $mob_url = "https://$vc_server/mob/?moid=$vm_moref&doPath=config"

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

    if($results.StatusCode -eq 200) {
        # Parsing HTML (ewww) from the vSphere MOB, using the vSphere SDKs once they are enabled for VMware Cloud on AWS will be simple 1-liner 
        $createDate = ($results.ParsedHtml.getElementsByTagName("TR") | where {$_.innerText -match "createDate"} | select innerText | ft -hide | Out-String).replace("createDatedateTime","").Replace("`"","").Trim()

        $creaeDateResults = [pscustomobject] @{
            Name = $vm.Name;
            CreateDate = $createDate;
        }
        return $creaeDateResults
    } else {
        Write-host "Failed to login to vSphere MOB"
        exit 1
    }

    # Logout out of vSphere MOB
    $mob_logout_url = "https://$vc_server/mob/logout"
    $logout = Invoke-WebRequest -Uri $mob_logout_url -WebSession $vmware -Method GET
}