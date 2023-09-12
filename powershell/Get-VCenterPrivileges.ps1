Function Get-VCenterPrivileges {
<#
    .DESCRIPTION Function to retreive privileges from vSphere privileges recorder
    .NOTES  Author:  William Lam
    .NOTES  Site:    www.williamlam.com
    .PARAMETER SessionToken
        Session Token returned from logging into vCenter REST API
    .PARAMETER Objects
        Array of vSphere Objects (type,id) to filter from privilege checks
    .PARAMETER Principals
        Array of vSphere Users (domain,name) to filter from privilege checks
    .PARAMETER OpIds
        Array of vSphere Operation Ids to filter from privilege checks
    .PARAMETER Sessions
        Array of vSphere Session IDs to filter from privilege checks
    .EXAMPLE
        # Filter privileges for Object of type VirtualMachine with MoRef ID vm-121005
        Get-VCenterPrivileges -SessionToken $sessionToken -Troubleshoot -Objects @(@{"type"="VirtualMachine";"id"="vm-121005"})
    .EXAMPLE
        # Filter privileges for Principal user with william@vsphere.local
        Get-VCenterPrivileges -SessionToken $sessionToken -Troubleshoot -Principals @(@{"domain"="vsphere.local";"name"="william"})
    .EXAMPLE
        # Filter privileges for Operation ID "create-marvel-vm"
        Get-VCenterPrivileges -SessionToken $sessionToken -Troubleshoot -OpIds @("create-marvel-vm")
    .EXAMPLE
        # Filter privileges for Session "52fcf343-ee6a-47b4-b3cf-58bca9f88424"
        Get-VCenterPrivileges -SessionToken $sessionToken -Troubleshoot -Sessions @("52fcf343-ee6a-47b4-b3cf-58bca9f88424")
    .EXAMPLE
        # Filter privileges for Object of type VirtualMachine with MoRef ID vm-121005 and for Principal user with william@vsphere.local
        Get-VCenterPrivileges -SessionToken $sessionToken -Troubleshoot -Objects @(@{"type"="VirtualMachine";"id"="vm-121005"}) -Principals @(@{"domain"="vsphere.local";"name"="william"})
#>
    param(
        [Parameter(Mandatory=$true)][string]$SessionToken,
        [Parameter(Mandatory=$false)][object[]]$Objects,
        [Parameter(Mandatory=$false)][object[]]$Principals,
        [Parameter(Mandatory=$false)][string[]]$OpIds,
        [Parameter(Mandatory=$false)][string[]]$Sessions,
        [Parameter(Mandatory=$false)][string]$Marker,
        [Switch]$Troubleshoot
    )

    $headers = @{
        "vmware-api-session-id"=$sessionToken
        "Content-Type"="application/json"
        "Accept"="application/json"
    }

    # Filter Spec
    $payload = @{
        filter = @{
        }
    }

    # Add Object to filter spec
    if($Objects) {
        $payload.filter.add("objects",$Objects)
    }

    # Add Principal to filter spec
    if($Principals) {
        $payload.filter.add("principals",$Principals)
    }

    # Add OpId to filter spec
    if($OpIds) {
        $payload.filter.add("op_ids",$OpIds)
    }

    if($Sessions) {
        $payload.filter.add("sessions",$Sessions)
    }

    $body = $payload | ConvertTo-Json -Depth 10

    $privCheckURL = "https://${vcenter_server}/api/vcenter/authorization/privilege-checks?action=list"

    # Include Marker
    if($Marker) {
        $privCheckURL = "${privCheckURL}&marker=${Marker}"
    }

    if($Troubleshoot) {
        Write-Host -ForegroundColor cyan "`n[DEBUG] - `n$privCheckURL`n"
        Write-Host -ForegroundColor cyan "[DEBUG]`n$body`n"
    }

    try {
        if($PSVersionTable.PSEdition -eq "Core") {
            $requests = Invoke-WebRequest -Uri $privCheckURL -Method POST -Body $body -Headers $headers -SkipCertificateCheck
        } else {
            $requests = Invoke-WebRequest -Uri $privCheckURL -Method POST -Body $body -Headers $headers
        }
    } catch {
        if($_.Exception.Response.StatusCode -eq "Unauthorized") {
            Write-Host -ForegroundColor Red "`nvCenter Server REST API session is no longer valid, please re-authenticate to retrieve a new token`n"
            break
        } else {
            Write-Error "Error in performing privilege check operation"
            Write-Error "`n($_.Exception.Message)`n"
            break
        }
    }

    if($requests.StatusCode -eq 200) {
        Write-Host -ForegroundColor Green "Marker: " -NoNewline
        # Print Marker
        Write-Host $(($requests.Content | ConvertFrom-Json).marker)
        # Print Privileges
        ($requests.Content | ConvertFrom-Json).items
    } else {
        Write-Host -ForegroundColor red "`nFailed to perform privilege check operation`n"
    }
}