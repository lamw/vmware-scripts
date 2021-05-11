Function Get-Esxconfig {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.williamlam.com
     Twitter:       @lamw
        ===========================================================================
    .DESCRIPTION
        This function remotely downloads /etc/vmware/config and outputs the content
    .PARAMETER VMHostName
        The name of an individual ESXi host
    .PARAMETER ClusterName
        The name vSphere Cluster
    .EXAMPLE
        Get-Esxconfig
    .EXAMPLE
        Get-Esxconfig -ClusterName cluster-01
    .EXAMPLE
        Get-Esxconfig -VMHostName esxi-01
#>
    param(
        [Parameter(Mandatory=$false)][String]$VMHostName,
        [Parameter(Mandatory=$false)][String]$ClusterName
    )

    if($ClusterName) {
        $cluster = Get-View -ViewType ClusterComputeResource -Property Name,Host -Filter @{"name"=$ClusterName}
        $vmhosts = Get-View $cluster.Host -Property Name
    } elseif($VMHostName) {
        $vmhosts = Get-View -ViewType HostSystem -Property Name -Filter @{"name"=$VMHostName}
    } else {
        $vmhosts = Get-View -ViewType HostSystem -Property Name
    }

    foreach ($vmhost in $vmhosts) {
        $vmhostIp = $vmhost.Name

        $sessionManager = Get-View ($global:DefaultVIServer.ExtensionData.Content.sessionManager)

        # URL to ESXi's esx.conf configuration file (can use any that show up under https://esxi_ip/host)
        $url = "https://$vmhostIp/host/vmware_config"

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
        Write-Host "Contents of /etc/vmware/config for $vmhostIp ...`n"
        return $result.content
    }
}

Function Remove-IntelSightingsWorkaround {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.williamlam.com
     Twitter:       @lamw
        ===========================================================================
    .DESCRIPTION
        This function removes the Intel Sightings workaround on an ESXi host as outline by https://kb.vmware.com/s/article/52345
    .PARAMETER AffectedHostList
        Text file containing ESXi Hostnames/IP for hosts you wish to remove remediation
    .EXAMPLE
        Remove-IntelSightingsWorkaround -AffectedHostList hostlist.txt
#>
    param(
        [Parameter(Mandatory=$true)][String]$AffectedHostList
    )

    Function UpdateESXConfig {
        param(
            $VMHost
        )

        $vmhostName = $vmhost.name

        $url = "https://$vmhostName/host/vmware_config"

        $sessionManager = Get-View ($global:DefaultVIServer.ExtensionData.Content.sessionManager)

        $spec = New-Object VMware.Vim.SessionManagerHttpServiceRequestSpec
        $spec.Method = "httpGet"
        $spec.Url = $url
        $ticket = $sessionManager.AcquireGenericServiceTicket($spec)

        $websession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
        $cookie = New-Object System.Net.Cookie
        $cookie.Name = "vmware_cgi_ticket"
        $cookie.Value = $ticket.id
        $cookie.Domain = $vmhost.name
        $websession.Cookies.Add($cookie)
        $result = Invoke-WebRequest -Uri $url -WebSession $websession
        $esxconfig = $result.content

        # Download the current config file to verify we have not already remediated
        # If not, store existing configuration and append new string
        $remediated = $false
        $newVMwareConfig = ""
        foreach ($line in $esxconfig.Split("`n")) {
            if($line -eq 'cpuid.7.edx = "----:00--:----:----:----:----:----:----"') {
                $remediated = $true
            } else {
                $newVMwareConfig+="$line`n"
            }
        }

        if($remediated -eq $true) {
            Write-Host "`tUpdating /etc/vmware/config ..."

            $newVMwareConfig = $newVMwareConfig.TrimEnd()
            $newVMwareConfig += "`n"

            # Create HTTP PUT spec
            $spec.Method = "httpPut"
            $spec.Url = $url
            $ticket = $sessionManager.AcquireGenericServiceTicket($spec)

            # Upload sfcb.cfg back to ESXi host
            $websession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
            $cookie.Name = "vmware_cgi_ticket"
            $cookie.Value = $ticket.id
            $cookie.Domain = $vmhost.name
            $websession.Cookies.Add($cookie)
            $result = Invoke-WebRequest -Uri $url -WebSession $websession -Body $newVMwareConfig -Method Put -ContentType "plain/text"
            if($result.StatusCode -eq 200) {
                Write-Host "`tSuccessfully updated VMware config file"
            } else {
                Write-Host "Failed to upload VMware config file"
                break
            }
        } else {
            Write-Host "Remedation not found, skipping host"
        }
    }

    if (Test-Path -Path $AffectedHostList) {
        $affectedHosts = Get-Content -Path $AffectedHostList
        foreach ($affectedHost in $affectedHosts) {
            try {
                $vmhost = Get-View -ViewType HostSystem -Property Name -Filter @{"name"=$affectedHost}
                Write-Host "Processing $affectedHost..."
                UpdateESXConfig -vmhost $vmhost
            } catch {
                Write-Host -ForegroundColor Yellow "Unable to find $affectedHost, skipping ..."
            }
        }
    } else {
        Write-Host -ForegroundColor Red "Can not find $AffectedHostList ..."
    }
}

Function Set-IntelSightingsWorkaround {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.williamlam.com
     Twitter:       @lamw
        ===========================================================================
    .DESCRIPTION
        This function removes the Intel Sightings workaround on an ESXi host as outline by https://kb.vmware.com/s/article/52345
    .PARAMETER AffectedHostList
        Text file containing ESXi Hostnames/IP for hosts you wish to apply remediation
    .EXAMPLE
        Set-IntelSightingsWorkaround -AffectedHostList hostlist.txt
#>
    param(
        [Parameter(Mandatory=$true)][String]$AffectedHostList
    )

    Function UpdateESXConfig {
        param(
            $vmhost
        )

        $vmhostName = $vmhost.name

        $url = "https://$vmhostName/host/vmware_config"

        $sessionManager = Get-View ($global:DefaultVIServer.ExtensionData.Content.sessionManager)

        $spec = New-Object VMware.Vim.SessionManagerHttpServiceRequestSpec
        $spec.Method = "httpGet"
        $spec.Url = $url
        $ticket = $sessionManager.AcquireGenericServiceTicket($spec)

        $websession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
        $cookie = New-Object System.Net.Cookie
        $cookie.Name = "vmware_cgi_ticket"
        $cookie.Value = $ticket.id
        $cookie.Domain = $vmhostName
        $websession.Cookies.Add($cookie)
        $result = Invoke-WebRequest -Uri $url -WebSession $websession
        $esxconfig = $result.content

        # Download the current config file to verify we have not already remediated
        # If not, store existing configuration and append new string
        $remediated = $false
        $newVMwareConfig = ""
        foreach ($line in $esxconfig.Split("`n")) {
            if($line -eq 'cpuid.7.edx = "----:00--:----:----:----:----:----:----"') {
                $remediated = $true
                break
            } else {
                $newVMwareConfig+="$line`n"
            }
        }

        if($remediated -eq $false) {
            Write-Host "`tUpdating /etc/vmware/config ..."

            $newVMwareConfig = $newVMwareConfig.TrimEnd()
            $newVMwareConfig+="`ncpuid.7.edx = `"----:00--:----:----:----:----:----:----`"`n"

            # Create HTTP PUT spec
            $spec.Method = "httpPut"
            $spec.Url = $url
            $ticket = $sessionManager.AcquireGenericServiceTicket($spec)

            # Upload sfcb.cfg back to ESXi host
            $websession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
            $cookie.Name = "vmware_cgi_ticket"
            $cookie.Value = $ticket.id
            $cookie.Domain = $vmhostName
            $websession.Cookies.Add($cookie)
            $result = Invoke-WebRequest -Uri $url -WebSession $websession -Body $newVMwareConfig -Method Put -ContentType "plain/text"
            if($result.StatusCode -eq 200) {
                Write-Host "`tSuccessfully updated VMware config file"
            } else {
                Write-Host "Failed to upload VMware config file"
                break
            }
        } else {
            Write-Host "Remedation aleady applied, skipping host"
        }
    }

    if (Test-Path -Path $AffectedHostList) {
        $affectedHosts = Get-Content -Path $AffectedHostList
        foreach ($affectedHost in $affectedHosts) {
            try {
                $vmhost = Get-View -ViewType HostSystem -Property Name -Filter @{"name"=$affectedHost}
                Write-Host "Processing $affectedHost..."
                UpdateESXConfig -vmhost $vmhost
            } catch {
                Write-Host -ForegroundColor Yellow "Unable to find $affectedHost, skipping ..."
            }
        }
    } else {
        Write-Host -ForegroundColor Red "Can not find $AffectedHostList ..."
    }
}
