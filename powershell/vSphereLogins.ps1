Function Get-vSphereLogins {
    <#
    .SYNOPSIS Retrieve information for all currently logged in vSphere Sessions (excluding current session)
    .NOTES  Author:  William Lam
    .NOTES  Site:    www.williamlam.com
    .REFERENCE Blog: http://www.williamlam.com/2016/11/an-update-on-how-to-retrieve-useful-information-from-a-vsphere-login.html 
    .EXAMPLE
      Get-vSphereLogins
    #>
    if($DefaultVIServers -eq $null) {
        Write-Host "Error: Please connect to your vSphere environment"
        exit
    }

    # Using the first connection
    $VCConnection = $DefaultVIServers[0]

    $sessionManager = Get-View ($VCConnection.ExtensionData.Content.SessionManager)

    # Store current session key
    $currentSessionKey = $sessionManager.CurrentSession.Key

    foreach ($session in $sessionManager.SessionList) {
        # Ignore vpxd-extension logins as well as the current session
        if($session.UserName -notmatch "vpxd-extension" -and $session.key -ne $currentSessionKey) {
            $session | Select Username, IpAddress, UserAgent, @{"Name"="APICount";Expression={$Session.CallCount}}, LoginTime
        }
    }
}
