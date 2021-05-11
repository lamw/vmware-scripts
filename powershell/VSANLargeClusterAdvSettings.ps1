Function Set-VsanLargeClusterAdvancedSetting {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.williamlam.com
     Twitter:       @lamw
        ===========================================================================
    .DESCRIPTION
        This function updates the ESXi Advanced Settings for enabling large vSAN Clusters
        for ESXi hosts running 5.5, 6.0 & 6.5 
    .PARAMETER ClusterName
        Name of the vSAN Cluster to update ESXi Advanced Settings for large vSAN Clusters
    .EXAMPLE
        Set-VsanLargeClusterAdvancedSetting -ClusterName VSAN-Cluster
#>
    param(
        [Parameter(Mandatory=$true)][String]$ClusterName
    )

    $cluster = Get-Cluster -Name $ClusterName -ErrorAction SilentlyContinue
    if($cluster -eq $null) {
        Write-Host -ForegroundColor Red "Error: Unable to find vSAN Cluster $ClusterName ..."
        break 
    }

    foreach ($vmhost in ($cluster | Get-VMHost)) {
        Write-Host "Updating Host:" $vmhost.name "..."
        # vSAN 6.x+ https://kb.vmware.com/kb/2110081
        if($vmhost.Version -eq "6.5.0") {
            Get-AdvancedSetting -Entity $vmhost -Name "VSAN.goto11" | Set-AdvancedSetting -Value 1 -Confirm:$false
            Get-AdvancedSetting -Entity $vmhost -Name "Net.TcpipHeapMax" | Set-AdvancedSetting -Value 1024 -Confirm:$false
        # vSAN 6.x+ https://kb.vmware.com/kb/2110081
        } elseif($vmhost.Version -eq "6.0.0") {
            Get-AdvancedSetting -Entity $vmhost -Name "VSAN.goto11" | Set-AdvancedSetting -Value 1 -Confirm:$false
            Get-AdvancedSetting -Entity $vmhost -Name "Net.TcpipHeapMax" | Set-AdvancedSetting -Value 1024 -Confirm:$false
            Get-AdvancedSetting -Entity $vmhost -Name "CMMDS.clientLimit" | Set-AdvancedSetting -Value 65 -Confirm:$false
        # vSAN 5.5 https://kb.vmware.com/kb/2073930
        } elseif($vmhost.Version -eq "5.5.0") {
            Get-AdvancedSetting -Entity $vmhost -Name "CMMDS.goto11" | Set-AdvancedSetting -Value 1 -Confirm:$false
        } else {
            Write-Host "$vmhost.Version is not a supported version for this script"
        }
    }
}

Function Get-VsanLargeClusterAdvancedSetting {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.williamlam.com
     Twitter:       @lamw
        ===========================================================================
    .DESCRIPTION
        This function retrieves the ESXi Advanced Settings for enabling large vSAN Clusters
        for ESXi hosts running 5.5, 6.0 & 6.5 
    .PARAMETER ClusterName
        Name of the vSAN Cluster to update ESXi Advanced Settings for large vSAN Clusters
    .EXAMPLE
        Get-VsanLargeClusterAdvancedSetting -ClusterName VSAN-Cluster
#>
    param(
        [Parameter(Mandatory=$true)][String]$ClusterName
    )

    $cluster = Get-Cluster -Name $ClusterName -ErrorAction SilentlyContinue
    if($cluster -eq $null) {
        Write-Host -ForegroundColor Red "Error: Unable to find vSAN Cluster $ClusterName ..."
        break 
    }

    foreach ($vmhost in ($cluster | Get-VMHost)) {
        Write-Host "Host:" $vmhost.name "..."
        if($vmhost.Version -eq "6.5.0") {
            Get-AdvancedSetting -Entity $vmhost -Name "VSAN.goto11"
            Get-AdvancedSetting -Entity $vmhost -Name "Net.TcpipHeapMax"
        } elseif($vmhost.Version -eq "6.0.0") {
            Get-AdvancedSetting -Entity $vmhost -Name "VSAN.goto11"
            Get-AdvancedSetting -Entity $vmhost -Name "Net.TcpipHeapMax"
            Get-AdvancedSetting -Entity $vmhost -Name "CMMDS.clientLimit"
        } elseif($vmhost.Version -eq "5.5.0") {
            Get-AdvancedSetting -Entity $vmhost -Name "CMMDS.goto11"
        } else {
            Write-Host "$vmhost.Version is not a supported version for this script"
        }
    }
}
