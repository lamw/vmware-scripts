Function Verify-ESXiMeltdownAccelerationInVM {
<#
    .NOTES
    ===========================================================================
     Created by:    Adam Robinson
     Organization:  University of Michigan
        ===========================================================================
    .DESCRIPTION
        This function helps verify if a virtual machine supports the PCID and INVPCID
        instructions.  These can be passed to guests with hardware version 11+
        and can provide performance improvements to Meltdown mitigation.

        This script can return all VMs or you can specify
        a vSphere Cluster to limit the scope or an individual VM
    .PARAMETER VMName
        The name of an individual Virtual Machine
    .EXAMPLE
        Verify-ESXiMeltdownAccelerationInVM
    .EXAMPLE
        Verify-ESXiMeltdownAccelerationInVM -ClusterName cluster-01
    .EXAMPLE
        Verify-ESXiMeltdownAccelerationInVM -VMName vm-01
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

            $PCIDPass = $false
            $INVPCIDPass = $false

            $cpuFeatures = $vm.Runtime.FeatureRequirement
            foreach ($cpuFeature in $cpuFeatures) {
                if($cpuFeature.key -eq "cpuid.PCID") {
                    $PCIDPass = $true
                } elseif($cpuFeature.key -eq "cpuid.INVPCID") {
                    $INVPCIDPass = $true
                }
            }

            $meltdownAcceleration = $false
            if ($PCIDPass -and $INVPCIDPass) {
                $meltdownAcceleration = $true
            }

            $tmp = [pscustomobject] @{
                VM = $vmDisplayName;
                PCID = $PCIDPass;
                INVPCID = $INVPCIDPass;
                vHW = $vmvHW;
                MeltdownAcceleration = $meltdownAcceleration
            }
            $results+=$tmp
        }
    }
    $results | ft
}
Function Verify-ESXiMeltdownAcceleration {
<#
    .NOTES
    ===========================================================================
     Created by:    Adam Robinson
     Organization:  University of Michigan
        ===========================================================================
    .DESCRIPTION
        This function helps verify if the ESXi host supports the PCID and INVPCID
        instructions.  These can be passed to guests with hardware version 11+
        and can provide performance improvements to Meltdown mitigation.

        This script can return all ESXi hosts or you can specify
        a vSphere Cluster to limit the scope or an individual ESXi host
    .PARAMETER VMHostName
        The name of an individual ESXi host
    .PARAMETER ClusterName
        The name vSphere Cluster
    .EXAMPLE
        Verify-ESXiMeltdownAcceleration
    .EXAMPLE
        Verify-ESXiMeltdownAcceleration -ClusterName cluster-01
    .EXAMPLE
        Verify-ESXiMeltdownAcceleration -VMHostName esxi-01
#>
    param(
        [Parameter(Mandatory=$false)][String]$VMHostName,
        [Parameter(Mandatory=$false)][String]$ClusterName
    )

    $accelerationEVCModes = @("intel-broadwell","intel-haswell","Disabled")

    if($ClusterName) {
        $cluster = Get-View -ViewType ClusterComputeResource -Property Name,Host -Filter @{"name"=$ClusterName}
        $vmhosts = Get-View $cluster.Host -Property Name,Config.FeatureCapability,Hardware.CpuFeature,Summary.CurrentEVCModeKey
    } elseif($VMHostName) {
        $vmhosts = Get-View -ViewType HostSystem -Property Name,Config.FeatureCapability,Hardware.CpuFeature,Summary.CurrentEVCModeKey -Filter @{"name"=$VMHostName}
    } else {
        $vmhosts = Get-View -ViewType HostSystem -Property Name,Config.FeatureCapability,Hardware.CpuFeature,Summary.CurrentEVCModeKey
    }

    $results = @()
    foreach ($vmhost in $vmhosts | Sort-Object -Property Name) {
        $vmhostDisplayName = $vmhost.Name

        $evcMode = $vmhost.Summary.CurrentEVCModeKey
        if ($evcMode -eq $null) {
            $evcMode = "Disabled"
        }

        $PCIDPass = $false
        $INVPCIDPass = $false

        #output from $vmhost.Hardware.CpuFeature is a binary string ':' delimited to nibbles
        #the easiest way I could figure out the hex conversion was to make a byte array
        $cpuidEAX = ($vmhost.Hardware.CpuFeature | Where-Object {$_.Level -eq 1}).Eax -Replace ":","" -Split "(?<=\G\d{8})(?=\d{8})"
        $cpuSignature = ($cpuidEAX | Foreach-Object {[System.Convert]::ToByte($_, 2)} | Foreach-Object {$_.ToString("X2")}) -Join ""
        $cpuSignature = "0x" + $cpuSignature

        $cpuFamily = [System.Convert]::ToByte($cpuidEAX[2], 2).ToString("X2")

        $cpuFeatures = $vmhost.Config.FeatureCapability
        foreach ($cpuFeature in $cpuFeatures) {
            if($cpuFeature.key -eq "cpuid.PCID" -and $cpuFeature.value -eq 1) {
                $PCIDPass = $true
            } elseif($cpuFeature.key -eq "cpuid.INVPCID" -and $cpuFeature.value -eq 1) {
                $INVPCIDPass = $true
            }
        }

        $HWv11Acceleration = $false
        if ($cpuFamily -eq "06") {
            if ($PCIDPass -and $INVPCIDPass) {
                if ($accelerationEVCModes -contains $evcMode) {
                    $HWv11Acceleration = $true
                }
                else {
                    $HWv11Acceleration = "EVCTooLow"
                }
            }
        }
        else {
            $HWv11Acceleration = "Unneeded"
        }

        $tmp = [pscustomobject] @{
            VMHost = $vmhostDisplayName;
            PCID = $PCIDPass;
            INVPCID = $INVPCIDPass;
            EVCMode = $evcMode
            "vHW11+Acceleration" = $HWv11Acceleration;
        }
        $results+=$tmp
    }
    $results | ft
}