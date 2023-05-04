<#PSScriptInfo
.VERSION 1.0.0
.GUID d893723e-86a9-4483-91e4-75f7a8a23b27
.AUTHOR William Lam
.COMPANYNAME VMware
.COPYRIGHT Copyright 2023, William Lam
.TAGS VMware
.LICENSEURI
.PROJECTURI https://github.com/lamw/vmware-scripts/blob/master/powershell/StandaloneHostvSpherePlusCPUSocketToCoreUsage.ps1
.ICONURI https://blogs.vmware.com/virtualblocks/files/2018/10/PowerCLI.png
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
    1.0.0 - Initial Release
.PRIVATEDATA
.DESCRIPTION This function retrieves vSphere+/vSAN+ CPU Core Usage Analysis for Standalone ESXi hosts (unmanaged)
#>

Function Get-StandalonevSpherePlusCPUSocketToCoreUsage {
<#
    .DESCRIPTION Retrieves vSphere+/vSAN+ CPU Core Usage Analysis for Standalone ESXi hosts (unmanaged)
    .NOTES  Author:  William Lam, VMware
    .PARAMETER InputFile
        Input text file containing list of standalone ESXi hosts delimited by hostname/ip,username,password.
        You can also comment out an entry if it starts with # symbol
    .PARAMETER Filename
        Specific filename to save CSV file (default: standalone-esxi-report-<date>.csv)
    .EXAMPLE
        Get-StandalonevSpherePlusCPUSocketToCoreUsage
    .EXAMPLE
        Get-StandalonevSpherePlusCPUSocketToCoreUsage -InputFile host.txt
    .EXAMPLE
        Get-StandalonevSpherePlusCPUSocketToCoreUsage -InputFile host.txt -CSV
    .EXAMPLE
        Get-StandalonevSpherePlusCPUSocketToCoreUsage -CSV -Filename myhosts.csv
#>
    param(
        [Parameter(Mandatory=$false)][string]$InputFile,
        [Parameter(Mandatory=$false)][string]$Filename,
        [Switch]$Csv
    )

    # Helper Function to build out CPU usage object
    Function BuildvSpherePlusCPUSocketToCoreUsage {
        param(
            [Parameter(Mandatory=$true)]$vmhost
        )

        $vmhostName = $vmhost.name

        $sockets = $vmhost.Hardware.CpuInfo.NumCpuPackages
        $coresPerSocket = ($vmhost.Hardware.CpuInfo.NumCpuCores / $sockets)

        # Check if hosts is running vSAN
        if($vmhost.Runtime.VsanRuntimeInfo.MembershipList -ne $null) {
            $isVSANHost = $true
        } else {
            $isVSANHost = $false
            $vsanPlusLicenseCount = 0
        }

        # vSphere+ & vSAN+
        if($coresPerSocket -le 16) {
            $vspherePlusLicenseCount = $sockets * 16
            if($isVSANHost) {
                $vsanPlusLicenseCount = $sockets * 16
            }
        } else {
            $vspherePlusLicenseCount =  $sockets * $coresPerSocket
            if($isVSANHost) {
                $vsanPlusLicenseCount = $sockets * $coresPerSocket
            }
        }

        $tmp = [pscustomobject] @{
            VMHOST = $vmhostName;
            NUM_CPU_SOCKETS = $sockets;
            NUM_CPU_CORES_PER_SOCKET = $coresPerSocket;
            VSPHEREPLUS_LICENSE_CORE_COUNT = $vspherePlusLicenseCount;
            VSANPLUS_LICENSE_CORE_COUNT = $vsanPlusLicenseCount
        }

        return $tmp
    }

    $results = @()
    foreach ($line in [System.IO.File]::ReadLines($InputFile)) {
        if($line -notmatch "^#") {
            $esxi_host,$esxi_username,$esxi_password = $line.split(",")

            Write-Host "Querying ${esxi_host} ..." -ForegroundColor Green

            $viConnection = Connect-VIServer -Server ${esxi_host} -User ${esxi_username} -Password ${esxi_password}

            $vmhost = Get-View -Server $viConnection -ViewType HostSystem -Property Name,Hardware.systemInfo,Hardware.CpuInfo,Runtime
            if($vmhost.Hardware.systemInfo.Model -ne "VMware Mobility Platform") {
                $result = BuildvSpherePlusCPUSocketToCoreUsage -vmhost $vmhost

                $results += $result
            }
            Disconnect-VIServer $viConnection -Confirm:$false
        }
    }

    if($CSV) {
        If(-Not $Filename) {
            $Filename = "standalone-esxi-report-$(Get-Date -Format 'MMddyyyTHHmmss').csv"
        }

        Write-Host "`nSaving output as CSV file to $Filename`n"
        $results | ConvertTo-Csv -NoTypeInformation | Out-File -FilePath $Filename
    } else {
        if (($results | measure).Count -eq 0)  {
            Write-Host "`nHosts were not found with searching criteria`n" -ForegroundColor Red
        } else {
            $results | ft
        }
    }
}