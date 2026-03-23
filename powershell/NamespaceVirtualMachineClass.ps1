<#
.SYNOPSIS
    Managing vSphere Virtual Machine Classes (vmclass) using vSphere Automation REST API

.DESCRIPTION
    List, Create and Delete Virtual Machine Classes using vSphere Automation REST API

    Workflow:
        1. $session = Connect-VSphereAutomationSession -Server <vc> -Credential <cred>
        2. Pass -Session $session to Get-, New-, Remove-NamespaceVirtualMachineClass and Disconnect-VSphereAutomationSession

    Session object (returned by Connect-VSphereAutomationSession):
        Server               [string]  vCenter FQDN or IP (no scheme)
        ApiSessionId         [string]  value for vmware-api-session-id header
        SkipCertificateCheck [bool]    if true, Invoke-WebRequest uses -SkipCertificateCheck (default on connect is $true)

    Credentials are only used inside Connect-VSphereAutomationSession; the session object holds the API session id, not the password.

    Prerequisites:
        - PowerShell 7+
        - VM class APIs on vCenter (vSphere API 7.0.2.00100+)

    Privileges:
        - Get-NamespaceVirtualMachineClass:     System.Read
        - New- / Remove-NamespaceVirtualMachineClass: VirtualMachineClasses.Manage

    REST (Broadcom vSphere Automation API):
        Session:     POST   /api/session
        Logout:      DELETE /api/session
        List:        GET    /api/vcenter/namespace-management/virtual-machine-classes
        Create:      POST   /api/vcenter/namespace-management/virtual-machine-classes
        Delete:      DELETE /api/vcenter/namespace-management/virtual-machine-classes/{vm_class}

.EXAMPLE
    # Source VM Class functions
    . .\NamespaceVirtualMachineClass.ps1

    # Login to vSphere Automation REST API
    $session = Connect-VSphereAutomationSession -Server sfo-m01-vc01.sfo.rainpole.io -Credential (Get-Credential)

    # List VM Classes
    Get-NamespaceVirtualMachineClass -Session $session | ft

    # Create new custom VM Class
    New-NamespaceVirtualMachineClass -Session $session -CpuCount 32 -MemoryMB 98304 -Name postgres-large -Description "PostgresDB Prod"
    New-NamespaceVirtualMachineClass -Session $session -CpuCount 16 -MemoryMB 49152 -Name postgres-medium -Description "PostgresDB Test"
    New-NamespaceVirtualMachineClass -Session $session -CpuCount 8 -MemoryMB 16384 -Name postgres-small -Description "PostgresDB Dev"

    # Remove VM Class
    Remove-NamespaceVirtualMachineClass -Session $session -Name postgres-large
    Remove-NamespaceVirtualMachineClass -Session $session -Name postgres-medium
    Remove-NamespaceVirtualMachineClass -Session $session -Name postgres-small

.EXAMPLE
    Enforce TLS certificate validation:

    $session = Connect-VSphereAutomationSession -Server vcenter.example.com -Credential $cred -SkipCertificateCheck:$false
#>

Function Connect-VSphereAutomationSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Server,

        [Parameter(Mandatory = $true)]
        [pscredential] $Credential,

        [Parameter()]
        [bool] $SkipCertificateCheck = $true
    )

    $user = $Credential.GetNetworkCredential().UserName
    $plain = $Credential.GetNetworkCredential().Password
    $basic = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${user}:${plain}"))

    $uri = "https://$Server/api/session"
    $request = @{
        Uri         = $uri
        Method      = 'Post'
        Headers     = @{
            Authorization = "Basic $basic"
            Accept        = 'application/json'
        }
        ContentType = 'application/json'
        ErrorAction = 'Stop'
    }
    if ($SkipCertificateCheck) {
        $request['SkipCertificateCheck'] = $true
    }

    try {
        $response = Invoke-WebRequest @request
    }
    catch {
        throw "Login failed for $uri : $($_.Exception.Message)"
    }

    $sessionValue = $response.Content | ConvertFrom-Json
    if ($sessionValue -is [string]) {
        $token = $sessionValue.Trim('"')
    }
    else {
        $token = [string]$sessionValue
    }

    if ([string]::IsNullOrWhiteSpace($token)) {
        throw 'Login succeeded but no session value was returned.'
    }

    Write-Verbose "Connected to $Server."

    return [pscustomobject]@{
        Server               = $Server.Trim()
        ApiSessionId         = $token
        SkipCertificateCheck = $SkipCertificateCheck
    }
}

Function Disconnect-VSphereAutomationSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject] $Session
    )

    if ([string]::IsNullOrWhiteSpace($Session.Server) -or [string]::IsNullOrWhiteSpace($Session.ApiSessionId)) {
        throw 'Invalid session object. Use Connect-VSphereAutomationSession.'
    }

    $uri = "https://$($Session.Server)/api/session"
    $request = @{
        Uri     = $uri
        Method  = 'Delete'
        Headers = @{
            'vmware-api-session-id' = $Session.ApiSessionId
            Accept                  = 'application/json'
        }
        ErrorAction = 'Stop'
    }
    if ($Session.SkipCertificateCheck) {
        $request['SkipCertificateCheck'] = $true
    }

    try {
        Invoke-WebRequest @request
    }
    catch {
        Write-Warning "Session delete failed (token may already be invalid): $($_.Exception.Message)"
    }
}

Function Get-NamespaceVirtualMachineClass {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject] $Session
    )

    if ([string]::IsNullOrWhiteSpace($Session.Server) -or [string]::IsNullOrWhiteSpace($Session.ApiSessionId)) {
        throw 'Invalid session object. Use Connect-VSphereAutomationSession.'
    }

    $uri = "https://$($Session.Server)/api/vcenter/namespace-management/virtual-machine-classes"
    $request = @{
        Uri     = $uri
        Method  = 'Get'
        Headers = @{
            'vmware-api-session-id' = $Session.ApiSessionId
            Accept                  = 'application/json'
        }
        ErrorAction = 'Stop'
    }
    if ($Session.SkipCertificateCheck) {
        $request['SkipCertificateCheck'] = $true
    }

    $response = Invoke-WebRequest @request
    if ([string]::IsNullOrWhiteSpace($response.Content)) {
        return $null
    }

    $vmclasses = $response.Content | ConvertFrom-Json

    $results = @()
    foreach ($vmclass in $vmclasses) {
        $cpuRes = $vmclass.cpu_reservation
        $memRes = $vmclass.memory_reservation
        $results += [pscustomobject]@{
            Name              = $vmclass.id
            CpuCount          = $vmclass.cpu_count
            MemoryMB          = $(if ($null -ne $vmclass.memory_mb) { $vmclass.memory_mb } else { $vmclass.memory_MB })
            CpuReservation    = if ($null -ne $cpuRes) { '{0}%' -f $cpuRes } else { $null }
            MemoryReservation = if ($null -ne $memRes) { '{0}%' -f $memRes } else { $null }
            Namespaces        = $vmclass.namespaces
            Description       = $vmclass.description
        }
    }

    return $results | Sort-Object -Property Name
}

Function New-NamespaceVirtualMachineClass {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject] $Session,

        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $CpuCount,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $MemoryMB,

        [Parameter()]
        [string] $Description
    )

    if ([string]::IsNullOrWhiteSpace($Session.Server) -or [string]::IsNullOrWhiteSpace($Session.ApiSessionId)) {
        throw 'Invalid session object. Use Connect-VSphereAutomationSession.'
    }

    # REST CreateSpec field is still "id"; -Name is the VM class identifier you choose
    $payload = [ordered]@{
        id         = $Name
        cpu_count  = $CpuCount
        memory_MB  = $MemoryMB
    }
    if (-not [string]::IsNullOrEmpty($Description)) {
        $payload['description'] = $Description
    }
    $json = $payload | ConvertTo-Json -Compress

    $uri = "https://$($Session.Server)/api/vcenter/namespace-management/virtual-machine-classes"
    $request = @{
        Uri         = $uri
        Method      = 'Post'
        Headers     = @{
            'vmware-api-session-id' = $Session.ApiSessionId
            Accept                  = 'application/json'
        }
        Body        = $json
        ContentType = 'application/json'
        ErrorAction = 'Stop'
    }
    if ($Session.SkipCertificateCheck) {
        $request['SkipCertificateCheck'] = $true
    }

    $response = Invoke-WebRequest @request
    if ([string]::IsNullOrWhiteSpace($response.Content)) {
        return $null
    }
    return $response.Content | ConvertFrom-Json
}

Function Remove-NamespaceVirtualMachineClass {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject] $Session,

        [Parameter(Mandatory = $true)]
        [string] $Name
    )

    if (-not $PSCmdlet.ShouldProcess($Name, 'Remove virtual machine class')) {
        return
    }

    if ([string]::IsNullOrWhiteSpace($Session.Server) -or [string]::IsNullOrWhiteSpace($Session.ApiSessionId)) {
        throw 'Invalid session object. Use Connect-VSphereAutomationSession.'
    }

    $encodedName = [uri]::EscapeDataString($Name)
    $uri = "https://$($Session.Server)/api/vcenter/namespace-management/virtual-machine-classes/$encodedName"
    $request = @{
        Uri     = $uri
        Method  = 'Delete'
        Headers = @{
            'vmware-api-session-id' = $Session.ApiSessionId
            Accept                  = 'application/json'
        }
        ErrorAction = 'Stop'
    }
    if ($Session.SkipCertificateCheck) {
        $request['SkipCertificateCheck'] = $true
    }

    $response = Invoke-WebRequest @request
    if ([string]::IsNullOrWhiteSpace($response.Content)) {
        return $null
    }
    return $response.Content | ConvertFrom-Json
}
