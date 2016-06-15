<#
.SYNOPSIS Remoting collecting esxcfg-info from an ESXi host using vCenter Server
.NOTES  Author:  William Lam
.NOTES  Site:    www.virtuallyghetto.com
.NOTES  Reference: http://www.virtuallyghetto.com/2016/06/using-the-vsphere-api-to-remotely-collect-esxi-esxcfg-info.html
.PARAMETER Vmhost
  ESXi host
.EXAMPLE
  PS> Get-VMHost -Name "esxi-1" | Get-Esxcfginfo
#>

Function Get-Esxcfginfo {
    param(
    [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    [VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl[]]$VMHost
    )

    $sessionManager = Get-View ($global:DefaultVIServer.ExtensionData.Content.sessionManager)

    # URL to the ESXi esxcfg-info info
    $url = "https://" + $vmhost.Name + "/cgi-bin/esxcfg-info.cgi?xml"

    $spec = New-Object VMware.Vim.SessionManagerHttpServiceRequestSpec
    $spec.Method = "httpGet"
    $spec.Url = $url
    $ticket = $sessionManager.AcquireGenericServiceTicket($spec)

    # Append the cookie generated from VC
    $websession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $cookie = New-Object System.Net.Cookie
    $cookie.Name = "vmware_cgi_ticket"
    $cookie.Value = $ticket.id
    $cookie.Domain = $vmhost.name
    $websession.Cookies.Add($cookie)

    # Retrieve file
    $result = Invoke-WebRequest -Uri $url -WebSession $websession -ContentType "application/xml"
    
    # cast output as an XML object
    return [ xml]$result.content
}

Connect-VIServer -Server 192.168.1.51 -User administrator@vghetto.local -password VMware1! | Out-Null

$xmlResult = Get-VMHost -Name "192.168.1.190" | Get-Esxcfginfo

# Extracting device-name, vendor-name & vendor-id as an example
foreach ($childnodes in $xmlResult.host.'hardware-info'.'pci-info'.'all-pci-devices'.'pci-device') {
   foreach ($childnode in $childnodes | select -ExpandProperty childnodes) {
    if($childnode.name -eq 'device-name') {
        $deviceName = $childnode.'#text'
    } elseif($childnode.name -eq 'vendor-name') {
        $vendorName = $childnode.'#text'
    } elseif($childnode.name -eq 'vendor-id') {
        $vendorId = $childnode.'#text'
    }
   }
   $deviceName
   $vendorName
   $vendorId
   Write-Host ""
}

Disconnect-VIServer * -Confirm:$false
