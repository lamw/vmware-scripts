Function Get-vSphereAPIUsage {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.virtuallyghetto.com
     Twitter:       @lamw
    ===========================================================================
    .DESCRIPTION
        This function returns the list of vSphere APIs used by specific vCenter Server
        session id and path to vpxd.log file
    .PARAMETER VpxdLogFile
        Full path to a vpxd.log file which has been downloaded remotely from a vCenter Server
    .PARAMETER SessionId
        The vCenter Server Session Id you wish to query
    .EXAMPLE
        Get-vSphereAPIUsage -VpxdLogFile "C:\Users\lamw\Dropbox\vpxd.log" -SessionId "52bb9a98-598d-26e9-46d0-ee85d3912646"
#>
    param(
        [Parameter(Mandatory=$true)]$VpxdLogFile,
        [Parameter(Mandatory=$true)]$SessionId
    )
    $vpxdLog = Get-Content -Path $VpxdLogFile

    $apiTally = @{}
    foreach ($line in $vpxdLog) {
        if($line -match $SessionId -and $line -match "[VpxLRO]" -and $line -match "BEGIN") {
            $field = $line -split " "
            if($field[13] -match "vim" -or $field[13] -match "vmodl") {
                $apiTally[$field[13]] += 1
            }
        }
    }
    $commandDuration = Measure-Command {
        $results = $apiTally.GetEnumerator() | Sort-Object -Property Value | FT -AutoSize @{Name=”vSphereAPI”;e={$_.Name}}, @{Name=”Frequency”; e={$_.Value}}
    }

    $duration = $commandDuration.TotalMinutes
    $fileSize = [math]::Round((Get-Item -Path $vpxdLogFile).Length / 1MB,2)
    Write-host "`nFileName: $vpxdLogFile"
    Write-host "FileSize: $fileSize MB"
    Write-Host "Duration: $duration minutes"
    $results
}
