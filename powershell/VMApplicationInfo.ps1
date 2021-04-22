Function Get-VMApplicationInfo {
<#
    .DESCRIPTION Retrieves discovered applications running inside of a VM
    .NOTES  Author:  William Lam
    .NOTES  Site:    www.virtuallyghetto.com
    .NOTES  Reference: http://www.virtuallyghetto.com/2019/12/application-discovery-in-vsphere-with-vmware-tools-11.html
    .PARAMETER VM
        VM Object
    .PARAMETER Output
        CSV or JSON output file
    .EXAMPLE
        Get-VMApplicationInfo -VM (Get-VM "DC-01")
    .EXAMPLE
        Get-VMApplicationInfo -VM (Get-VM "DC-01") -UniqueOnly
    .EXAMPLE
        Get-VMApplicationInfo -VM (Get-VM "DC-01") -Output CSV
    .EXAMPLE
        Get-VMApplicationInfo -VM (Get-VM "DC-01") -Output JSON
#>
    param(
        [Parameter(Mandatory=$true)]$VM,
        [Parameter(Mandatory=$false)][ValidateSet("CSV","JSON")][String]$Output,
        [Parameter(Mandatory=$false)][Switch]$UniqueOnly
    )

    $appInfoValue = (Get-AdvancedSetting -Entity $VM -Name "guestinfo.appInfo").Value

    if($appInfoValue -eq $null) {
        Write-Host "Application Discovery has not been enabled for this VM"
    } else {
        $appInfo = $appInfoValue | ConvertFrom-Json
        $appUpdateVersion = $appInfo.updateCounter

        if($UniqueOnly) {
            $results = $appInfo.applications | Sort-Object -Property a -Unique| Select-Object @{Name="Application";e={$_.a}},@{Name="Version";e={$_.v}}
        } else {
            $results = $appInfo.applications | Sort-Object -Property a | Select-Object @{Name="Application";e={$_.a}},@{Name="Version";e={$_.v}}
        }

        Write-Verbose "Application Discovery Time: $($appInfo.publishTime)"
        if($Output -eq "CSV") {
            $fileOutputName = "$($VM.name)-version-$($appUpdateVersion)-apps.csv"

            Write-Host "`tSaving output to $fileOutputName"
            ($appInfo.applications) | ConvertTo-Csv | Out-File -FilePath "$fileOutputName"
        } elseif ($Output -eq "JSON") {
            $fileOutputName = "$($VM.name)-version-$($appUpdateVersion)-apps.json"

            Write-Host "`tSaving output to $fileOutputName"
            ($appInfo.applications) | ConvertTo-Json | Out-File -FilePath "$fileOutputName"
        } else {
            $results
        }
    }
}
