Function Verify-ESXiMicrocodePatchAndVM {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.virtuallyghetto.com
     Twitter:       @lamw
        ===========================================================================
    .DESCRIPTION
        This function helps verify both ESXi Patch and Microcode updates have been
        applied as stated per https://kb.vmware.com/s/article/52085

        This script can return all VMs or you can specify
        a vSphere Cluster to limit the scope or an individual VM
    .PARAMETER VMName
        The name of an individual Virtual Machine
    .EXAMPLE
        Verify-ESXiMicrocodePatchAndVM
    .EXAMPLE
        Verify-ESXiMicrocodePatchAndVM -ClusterName cluster-01
    .EXAMPLE
        Verify-ESXiMicrocodePatchAndVM -VMName vm-01
#>
    param(
        [Parameter(Mandatory=$false)][String]$VMName,
        [Parameter(Mandatory=$false)][String]$ClusterName
    )

    if($ClusterName) {
        $cluster = Get-View -ViewType ClusterComputeResource -Property Name,ResourcePool -Filter @{"name"=$ClusterName}
        $vms = Get-View ((Get-View $cluster.ResourcePool).VM) -Property Name,Config.Version,Runtime.PowerState,Runtime.FeatureRequirement
    } elseif($VMName) {
        $vms = Get-View -ViewType VirtualMachine -Property Name,Config.Version,Runtime.PowerState,Runtime.FeatureRequirement -Filter @{"name"=$VMName}
    } else {
        $vms = Get-View -ViewType VirtualMachine -Property Name,Config.Version,Runtime.PowerState,Runtime.FeatureRequirement
    }

    $results = @()
    foreach ($vm in $vms | Sort-Object -Property Name) {
        # Only check VMs that are powered on
        if($vm.Runtime.PowerState -eq "poweredOn") {
            $vmDisplayName = $vm.Name
            $vmvHW = $vm.Config.Version

            $vHWPass = $false
            if($vmvHW -eq "vmx-04" -or $vmvHW -eq "vmx-06" -or $vmvHW -eq "vmx-07" -or $vmvHW -eq "vmx-08") {
                $vHWPass = "N/A"
            } elseif($vmvHW -eq "vmx-09" -or $vmvHW -eq "vmx-10" -or $vmvHW -eq "vmx-11" -or $vmvHW -eq "vmx-12" -or $vmvHW -eq "vmx-13") {
                $vHWPass = $true
            }

            $IBRSPass = $false
            $IBPBPass = $false
            $STIBPPass = $false

            $cpuFeatures = $vm.Runtime.FeatureRequirement
            foreach ($cpuFeature in $cpuFeatures) {
                if($cpuFeature.key -eq "cpuid.IBRS") {
                    $IBRSPass = $true
                } elseif($cpuFeature.key -eq "cpuid.IBPB") {
                    $IBPBPass = $true
                } elseif($cpuFeature.key -eq "cpuid.STIBP") {
                    $STIBPPass = $true
                }
            }

            $vmAffected = $true
            if( ($IBRSPass -eq $true -or $IBPBPass -eq $true -or $STIBPPass -eq $true) -and $vHWPass -eq $true) {
                $vmAffected = $false
            } elseif($vHWPass -eq "N/A") {
                $vmAffected = $vHWPass
            }

            $tmp = [pscustomobject] @{
                VM = $vmDisplayName;
                IBRPresent = $IBRSPass;
                IBPBPresent = $IBPBPass;
                STIBPresent = $STIBPPass;
                vHW = $vmvHW;
                Affected = $vmAffected;
            }
            $results+=$tmp
        }
    }
    $results | ft
}

Function Verify-ESXiMicrocodePatch {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.virtuallyghetto.com
     Twitter:       @lamw
        ===========================================================================
    .DESCRIPTION
        This function helps verify only the ESXi Microcode update has been
        applied as stated per https://kb.vmware.com/s/article/52085

        This script can return all ESXi hosts or you can specify
        a vSphere Cluster to limit the scope or an individual ESXi host
    .PARAMETER VMHostName
        The name of an individual ESXi host
    .PARAMETER ClusterName
        The name vSphere Cluster
    .EXAMPLE
        Verify-ESXiMicrocodePatch
    .EXAMPLE
        Verify-ESXiMicrocodePatch -ClusterName cluster-01
    .EXAMPLE
        Verify-ESXiMicrocodePatch -VMHostName esxi-01
#>
    param(
        [Parameter(Mandatory=$false)][String]$VMHostName,
        [Parameter(Mandatory=$false)][String]$ClusterName
    )

    if($ClusterName) {
        $cluster = Get-View -ViewType ClusterComputeResource -Property Name,Host -Filter @{"name"=$ClusterName}
        $vmhosts = Get-View $cluster.Host -Property Name,Config.FeatureCapability
    } elseif($VMHostName) {
        $vmhosts = Get-View -ViewType HostSystem -Property Name,Config.FeatureCapability -Filter @{"name"=$VMHostName}
    } else {
        $vmhosts = Get-View -ViewType HostSystem -Property Name,Config.FeatureCapability
    }

    $results = @()
    foreach ($vmhost in $vmhosts | Sort-Object -Property Name) {
        $vmhostDisplayName = $vmhost.Name

        $IBRSPass = $false
        $IBPBPass = $false
        $STIBPPass = $false

        $cpuFeatures = $vmhost.Config.FeatureCapability
        foreach ($cpuFeature in $cpuFeatures) {
            if($cpuFeature.key -eq "cpuid.IBRS" -and $cpuFeature.value -eq 1) {
                $IBRSPass = $true
            } elseif($cpuFeature.key -eq "cpuid.IBPB" -and $cpuFeature.value -eq 1) {
                $IBPBPass = $true
            } elseif($cpuFeature.key -eq "cpuid.STIBP" -and $cpuFeature.value -eq 1) {
                $STIBPPass = $true
            }
        }

        $vmhostAffected = $true
        if($IBRSPass -or $IBPBPass -or $STIBPass) {
           $vmhostAffected = $false
        }

        $tmp = [pscustomobject] @{
            VMHost = $vmhostDisplayName;
            IBRPresent = $IBRSPass;
            IBPBPresent = $IBPBPass;
            STIBPresent = $STIBPPass;
            Affected = $vmhostAffected;
        }
        $results+=$tmp
    }
    $results | ft
}
