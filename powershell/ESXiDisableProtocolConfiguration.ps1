Function Get-ESXiDPC {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.virtuallyghetto.com
     Twitter:       @lamw
        ===========================================================================
    .DESCRIPTION
        This function retreives the current disabled TLS protocols for all ESXi
        hosts within a vSphere Cluster
    .SYNOPSIS
        Returns current disabled TLS protocols for Hostd, Authd, sfcbd & VSANVP/IOFilter 
    .PARAMETER Cluster
        The name of the vSphere Cluster
    .EXAMPLE
        Get-ESXiDPC -Cluster VSAN-Cluster
#>
    param(
        [Parameter(Mandatory=$true)][String]$Cluster
    )

    $debug = $false
	if ( $global:DefaultVIServers.Count -ne 1 ) {
		write-error "Need to be connected to exactly ONE vCenter. Please try again"
		return
	}

    Function Get-SFCBDConf {
        param(
            [VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl]$VMHost
        )

        $url = "https://$vmhost/host/sfcb.cfg"

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
        $sfcbConf = $result.content
        
        # Extract the TLS fields if they exists
        $sfcbResults = @()
        $usingDefault = $true
        foreach ($line in $sfcbConf.Split("`n")) {
            if($line -match "enableTLSv1:") {
                ($key,$value) = $line.Split(":")
                if($value -match "false") {
                    $sfcbResults+="tlsv1"
                }
                $usingDefault = $false
            }
            if($line -match "enableTLSv1_1:") {
                ($key,$value) = $line.Split(":")
                if($value -match "false") {
                    $sfcbResults+="tlsv1.1"
                }
                $usingDefault = $false
            }
            if($line -match "enableTLSv1_2:") {
                ($key,$value) = $line.Split(":")
                if($value -match "false") {
                    $sfcbResults+="tlsv1.2"
                }
                $usingDefault = $false
            }
        }
        if($usingDefault -or ($sfcbResults.Length -eq 0)) {
            $sfcbResults = "tlsv1,tlsv1.1,sslv3"
            return $sfcbResults
        } else {
            $sfcbResults+="sslv3"
            return $sfcbResults -join ","
        }
    }

    $results = @()
    foreach ($vmhost in (Get-Cluster -Name $Cluster | Get-VMHost)) {
        if( ($vmhost.ApiVersion -eq "6.0" -and (Get-AdvancedSetting -Entity $vmhost -Name "Misc.HostAgentUpdateLevel").value -eq "3") -or ($vmhost.ApiVersion -eq "6.5") ) {
            $esxiVersion = ($vmhost.ApiVersion) + " Update " + (Get-AdvancedSetting -Entity $vmhost -Name "Misc.HostAgentUpdateLevel").value
            
            $vps = (Get-AdvancedSetting -Entity $vmhost -Name "UserVars.ESXiVPsDisabledProtocols" -ErrorAction SilentlyContinue).value
            # ESXi 6.5 - UserVars.ESXiVPsDisabledProtocols covers both VPs+rHTTP
            if($vmhost.ApiVersion -eq "6.5") {
                $rhttpProxy = $vps
                # Only TLS 1.2 is enabled 
                $vmauth = "tlsv1,tlsv1.1,sslv3"
            } else {
                $rhttpProxy = (Get-AdvancedSetting -Entity $vmhost -Name "UserVars.ESXiRhttpproxyDisabledProtocols" -ErrorAction SilentlyContinue).value
                $vmauth = (Get-AdvancedSetting -Entity $vmhost -Name "UserVars.VMAuthdDisabledProtocols" -ErrorAction SilentlyContinue).value
            }
            $sfcbd = Get-SFCBDConf -vmhost $vmhost

            $hostTLSSettings = [pscustomobject] @{
                vmhost = $vmhost.name;
                version = $esxiVersion;
                hostd = $rhttpProxy;
                authd = $vmauth;
                sfcbd = $sfcbd
                ioFilterVSANVP = $vps
            }
            $results+=$hostTLSSettings
        }
    }
    Write-Host -NoNewline "`nDisabled Protocols on all ESXi hosts:"
    $results
}

Function Set-ESXiDPC {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.virtuallyghetto.com
     Twitter:       @lamw
        ===========================================================================
    .DESCRIPTION
        This function configures the TLS protocols to disable for all 
        ESXi hosts within a vSphere Cluster
    .SYNOPSIS
        Configures the disabled TLS protocols for Hostd, Authd, sfcbd & VSANVP/IOFilter 
    .PARAMETER Cluster
        The name of the vSphere Cluster
    .EXAMPLE
        Set-ESXiDPC -Cluster VSAN-Cluster -TLS1 $true -TLS1_1 $true -TLS1_2 $false -SSLV3 $true
#>
    param(
        [Parameter(Mandatory=$true)][String]$Cluster,
        [Parameter(Mandatory=$true)][Boolean]$TLS1,
        [Parameter(Mandatory=$true)][Boolean]$TLS1_1,
        [Parameter(Mandatory=$true)][Boolean]$TLS1_2,
        [Parameter(Mandatory=$true)][Boolean]$SSLV3
    )
	if ( $global:DefaultVIServers.Count -ne 1 ) {
		write-error "Need to be connected to exactly ONE vCenter. Please try again"
		return
	}

    Function UpdateSFCBConfig {
        param(
            [VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl]$VMHost
        )

        $url = "https://$vmhost/host/sfcb.cfg"

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
        $sfcbConf = $result.content
        
        # Download the current sfcb.cfg and ignore existing TLS configuration
        $sfcbResults = ""
        foreach ($line in $sfcbConf.Split("`n")) {
            if($line -notmatch "enableTLSv1:" -and $line -notmatch "enableTLSv1_1:" -and $line -notmatch "enableTLSv1_2:" -and $line -ne "") {
                $sfcbResults+="$line`n"
            }
        }
        
        # Append the TLS protocols based on user input to the configuration file
        $sfcbResults+="enableTLSv1: " + (!$TLS1).ToString().ToLower() + "`n"
        $sfcbResults+="enableTLSv1_1: " + (!$TLS1_1).ToString().ToLower() + "`n"
        $sfcbResults+="enableTLSv1_2: " + (!$TLS1_2).ToString().ToLower() +"`n"

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
        $result = Invoke-WebRequest -Uri $url -WebSession $websession -Body $sfcbResults -Method Put -ContentType "plain/text"
        if($result.StatusCode -eq 200) {
            Write-Host "`tSuccessfully updated sfcb.cfg file"
        } else {
            Write-Host "Failed to upload sfcb.cfg file"
            break
        }
    }

    # Build TLS string based on user input for setting ESXi Advanced Settings
    if($TLS1 -and $TLS1_1 -and $TLS1_2 -and $SSLV3) {
        Write-Host -ForegroundColor Red "Error: You must at least enable one of the TLS protocols"
        break
    }

    $tlsString = @()
    if($TLS1) { $tlsString += "tlsv1" }
    if($TLS1_1) { $tlsString += "tlsv1.1" }
    if($TLS1_2) { $tlsString += "tlsv1.2" }
    if($SSLV3) { $tlsString += "sslv3" }
    $tlsString = $tlsString -join ","

    Write-Host "`nDisabling the following TLS protocols: $tlsString on ESXi hosts ...`n"
    foreach ($vmhost in (Get-Cluster -Name $Cluster | Get-VMHost)) {
        if( ($vmhost.ApiVersion -eq "6.0" -and (Get-AdvancedSetting -Entity $vmhost -Name "Misc.HostAgentUpdateLevel").value -eq "3") -or ($vmhost.ApiVersion -eq "6.5") ) {
            Write-Host "Updating $vmhost ..."

            Write-Host "`tUpdating sfcb.cfg ..."
            UpdateSFCBConfig -vmhost $vmhost

            if($vmhost.ApiVersion -eq "6.0") {
                Write-Host "`tUpdating UserVars.ESXiRhttpproxyDisabledProtocols ..."
                Get-AdvancedSetting -Entity $vmhost -Name "UserVars.ESXiRhttpproxyDisabledProtocols" | Set-AdvancedSetting -Value $tlsString -Confirm:$false | Out-Null

                Write-Host "`tUpdating UserVars.VMAuthdDisabledProtocols ..."
                Get-AdvancedSetting -Entity $vmhost -Name "UserVars.VMAuthdDisabledProtocols" | Set-AdvancedSetting -Value $tlsString -Confirm:$false | Out-Null
            }
            Write-Host "`tUpdating UserVars.ESXiVPsDisabledProtocols ..."
            Get-AdvancedSetting -Entity $vmhost -Name "UserVars.ESXiVPsDisabledProtocols" | Set-AdvancedSetting -Value $tlsString -Confirm:$false | Out-Null
        }
    }
}
