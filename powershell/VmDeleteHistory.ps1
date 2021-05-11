<#PSScriptInfo
.VERSION 1.0.0
.GUID 62fd99cb-5129-47b4-ae95-8bdf31d829dc
.AUTHOR William Lam
.COMPANYNAME VMware
.COPYRIGHT Copyright 2021, William Lam
.TAGS VMware VM Deleted
.LICENSEURI
.PROJECTURI https://github.com/lamw/vghetto-scripts/blob/master/powershell/VmDeleteHistory.ps1
.ICONURI https://blogs.vmware.com/virtualblocks/files/2018/10/PowerCLI.png
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
    1.0.0 - Initial Release
.PRIVATEDATA
.DESCRIPTION This function retrieves information about deleted VMs
#>
Function Get-VMDeleteHistory {
   <#
        .NOTES
        ===========================================================================
        Created by:    William Lam
        Organization:  VMware
        Blog:          www.williamlam.com
        Twitter:       @lamw
        ===========================================================================
        .PARAMETER MaxSamples
            Specifies the maximum number of retrieved events (default 500)
        .EXAMPLE
            Get-VMDeleteHistory
        .EXAMPLE
            Get-VMDeleteHistory -MaxSamples 100
    #>
    param(
        [Parameter(Mandatory=$false)]$MaxSamples=500
    )

    $results = @()
    $events = Get-VIEvent -MaxSamples $MaxSamples -Types Info | where {$_.GetType().Name -eq "TaskEvent" -and $_.FullFormattedMessage -eq "Task: Delete virtual machine" }

    foreach ($event in $events) {
        $tmp = [pscustomobject] @{
            VM = $event.Vm.Name;
            User = $event.UserName;
            Date = $event.CreatedTime;
        }
        $results += $tmp
    }
    $results
}
