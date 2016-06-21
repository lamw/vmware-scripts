<#
.SYNOPSIS Remoting collecting ESXi configuration files using vCenter Server
.NOTES  Author:  William Lam
.NOTES  Site:    www.virtuallyghetto.com
.NOTES  Reference: http://www.virtuallyghetto.com/2016/06/using-the-vsphere-api-to-remotely-collect-esxi-configuration-files.html
.PARAMETER Vmhost
  ESXi host
.EXAMPLE
  PS> Get-VMHost -Name "esxi-1" | Get-Esxconf
#>

Function Get-Esxconf {
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

    # URL to ESXi's esx.conf configuration file (can use any that show up under https://esxi_ip/host)
    $url = "https://192.168.1.190/host/esx.conf"

    # URL to the ESXi configuration file
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
    $result = Invoke-WebRequest -Uri $url -WebSession $websession
    return $result.content
}

Connect-VIServer -Server 192.168.1.51 -User administrator@vghetto.local -password VMware1! | Out-Null

$esxConf = Get-VMHost -Name "192.168.1.190" | Get-Esxconf

$esxConf

Disconnect-VIServer * -Confirm:$false