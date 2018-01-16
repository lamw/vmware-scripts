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
                IBRSPresent = $IBRSPass;
                IBPBPresent = $IBPBPass;
                STIBPPresent = $STIBPPass;
                vHW = $vmvHW;
                HypervisorAssistedGuestAffected = $vmAffected;
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
    .EXAMPLE
        Verify-ESXiMicrocodePatch -ClusterName "Virtual SAN Cluster" -IncludeMicrocodeVerCheck $true -PlinkPath "C:\Users\lamw\Desktop\plink.exe" -ESXiUsername "root" -ESXiPassword "foobar"
#>
    param(
        [Parameter(Mandatory=$false)][String]$VMHostName,
        [Parameter(Mandatory=$false)][String]$ClusterName,
        [Parameter(Mandatory=$false)][Boolean]$IncludeMicrocodeVerCheck=$false,
        [Parameter(Mandatory=$false)][String]$PlinkPath,
        [Parameter(Mandatory=$false)][String]$ESXiUsername,
        [Parameter(Mandatory=$false)][String]$ESXiPassword
    )

    if($ClusterName) {
        $cluster = Get-View -ViewType ClusterComputeResource -Property Name,Host -Filter @{"name"=$ClusterName}
        $vmhosts = Get-View $cluster.Host -Property Name,Config.FeatureCapability,Hardware.CpuFeature,Summary.Hardware,ConfigManager.ServiceSystem
    } elseif($VMHostName) {
        $vmhosts = Get-View -ViewType HostSystem -Property Name,Config.FeatureCapability,Hardware.CpuFeature,Summary.Hardware,ConfigManager.ServiceSystem -Filter @{"name"=$VMHostName}
    } else {
        $vmhosts = Get-View -ViewType HostSystem -Property Name,Config.FeatureCapability,Hardware.CpuFeature,Summary.Hardware,ConfigManager.ServiceSystem
    }

    #List from https://kb.vmware.com/s/article/52345
    $intelSightings = @("0x000306C3", "0x000306F2", "0x000306F4", "0x00040671", "0x000406F1", "0x000406F1", "0x00050663")

    #List of blacklisted Microcode containing Intel Sighting issue from https://kb.vmware.com/s/article/52345
    $intelSightingsMicrocodeVersion = @("0x00000023", "0x00000023", "0x0000003B", "0x0000001B", "0x0B000025", "0x07000011")

    # Remote SSH commands for retrieving current ESXi host microcode version
    $plinkoptions = "-ssh -pw $ESXiPassword"
    $cmd = "vsish -e cat /hardware/cpu/cpuList/0 | grep `'Current Revision:`'"
    $remoteCommand = '"' + $cmd + '"'

    $results = @()
    foreach ($vmhost in $vmhosts | Sort-Object -Property Name) {
        $vmhostDisplayName = $vmhost.Name
        $cpuModel = $vmhost.Summary.Hardware.CpuModel

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

        # Retrieve Microcode version if user specifies which unfortunately requires SSH access
        if($IncludeMicrocodeVerCheck -and $PlinkPath -ne $null -and $ESXiUsername -ne $null -and $ESXiPassword -ne $null) {
            $serviceSystem = Get-View $vmhost.ConfigManager.ServiceSystem
            $services = $serviceSystem.ServiceInfo.Service
            foreach ($service in $services) {
                if($service.Key -eq "TSM-SSH") {
                    $ssh = $service
                    break
                }
            }

            $command = "echo yes | " + $PlinkPath + " " + $plinkoptions + " " + $ESXiUsername + "@" + $vmhost.Name + " " + $remoteCommand

            if($ssh.Running){
                $plinkResults = Invoke-Expression -command $command
                $microcodeVersion = $plinkResults.split(":")[1]
            } else {
                $microcodeVersion = "SSHNeedsToBeEnabled"
            }
        } else {
            $microcodeVersion = "N/A"
        }

        #output from $vmhost.Hardware.CpuFeature is a binary string ':' delimited to nibbles
        #the easiest way I could figure out the hex conversion was to make a byte array
        $cpuidEAX = ($vmhost.Hardware.CpuFeature | Where-Object {$_.Level -eq 1}).Eax -Replace ":","" -Split "(?<=\G\d{8})(?=\d{8})"
        $cpuSignature = ($cpuidEAX | Foreach-Object {[System.Convert]::ToByte($_, 2)} | Foreach-Object {$_.ToString("X2")}) -Join ""
        $cpuSignature = "0x" + $cpuSignature

        $cpuFamily = [System.Convert]::ToByte($cpuidEAX[2], 2).ToString("X2")
        #$cpuModel = [System.Convert]::ToByte($cpuidEAX[3], 2).ToString("X2")
        #$cpuStepping = [System.Convert]::ToByte($cpuidEAX[1], 2).ToString("X2")

        #no need to check the CPU for IntelSightings if we aren't on Intel
        if ($cpuFamily -eq "06") {
            $intelSighting = $false

            # More robust validaion as we're checing BOTH CPU type + affected microcode version as outlined in the KB
            if($IncludeMicrocodeVerCheck) {
                if( ($intelSightings -contains $cpuSignature) -and ($intelSightingsMicrocodeVersion -contains $microcodeVersion)) {
                    if ($vmhostAffected -eq $true) {
                        $intelSighting = "AffectedOncePatched"
                    }
                    else {
                        $intelSighting = $true
                    }
                }
            } else {
                if( $intelSightings -contains $cpuSignature) {
                    if ($vmhostAffected -eq $true) {
                        $intelSighting = "AffectedOncePatched"
                    }
                    else {
                        $intelSighting = $true
                    }
                }
            }
        }
        else {
            $IntelSighting = "n/a"
        }

        $tmp = [pscustomobject] @{
            VMHost = $vmhostDisplayName;
            CPU = $cpuModel;
            Microcode = $microcodeVersion;
            IBRSPresent = $IBRSPass;
            IBPBPresent = $IBPBPass;
            STIBPPresent = $STIBPPass;
            HypervisorAssistedGuestAffected = $vmhostAffected;
            IntelSighting = $intelSighting;
        }
        $results+=$tmp
    }
    $results | FT
}
