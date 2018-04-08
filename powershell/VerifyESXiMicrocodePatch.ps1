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

    # Merge of tables from https://kb.vmware.com/s/article/52345 and https://kb.vmware.com/s/article/52085
    $procSigUcodeTable = @(
	    [PSCustomObject]@{Name = "Sandy Bridge DT";  procSig = "0x000206a7"; ucodeRevFixed = "0x0000002d"; ucodeRevSightings = ""}
	    [PSCustomObject]@{Name = "Sandy Bridge EP";  procSig = "0x000206d7"; ucodeRevFixed = "0x00000713"; ucodeRevSightings = ""}
	    [PSCustomObject]@{Name = "Ivy Bridge DT";  procSig = "0x000306a9"; ucodeRevFixed = "0x0000001f"; ucodeRevSightings = ""}
	    [PSCustomObject]@{Name = "Ivy Bridge EP";  procSig = "0x000306e4"; ucodeRevFixed = "0x0000042c"; ucodeRevSightings = "0x0000042a"}
	    [PSCustomObject]@{Name = "Ivy Bridge EX";  procSig = "0x000306e7"; ucodeRevFixed = "0x00000713"; ucodeRevSightings = ""}
	    [PSCustomObject]@{Name = "Haswell DT";  procSig = "0x000306c3"; ucodeRevFixed = "0x00000024"; ucodeRevSightings = "0x00000023"}
	    [PSCustomObject]@{Name = "Haswell EP";  procSig = "0x000306f2"; ucodeRevFixed = "0x0000003c"; ucodeRevSightings = "0x0000003b"}
	    [PSCustomObject]@{Name = "Haswell EX";  procSig = "0x000306f4"; ucodeRevFixed = "0x00000011"; ucodeRevSightings = "0x00000010"}
	    [PSCustomObject]@{Name = "Broadwell H";  procSig = "0x00040671"; ucodeRevFixed = "0x0000001d"; ucodeRevSightings = "0x0000001b"}
	    [PSCustomObject]@{Name = "Broadwell EP/EX";  procSig = "0x000406f1"; ucodeRevFixed = "0x0b00002a"; ucodeRevSightings = "0x0b000025"}
	    [PSCustomObject]@{Name = "Broadwell DE";  procSig = "0x00050662"; ucodeRevFixed = "0x00000015"; ucodeRevSightings = ""}
	    [PSCustomObject]@{Name = "Broadwell DE";  procSig = "0x00050663"; ucodeRevFixed = "0x07000012"; ucodeRevSightings = "0x07000011"}
	    [PSCustomObject]@{Name = "Broadwell DE";  procSig = "0x00050664"; ucodeRevFixed = "0x0f000011"; ucodeRevSightings = ""}
	    [PSCustomObject]@{Name = "Broadwell NS";  procSig = "0x00050665"; ucodeRevFixed = "0x0e000009"; ucodeRevSightings = ""}
	    [PSCustomObject]@{Name = "Skylake H/S";  procSig = "0x000506e3"; ucodeRevFixed = "0x000000c2"; ucodeRevSightings = ""} # wasn't actually affected by Sightings, ucode just re-released
	    [PSCustomObject]@{Name = "Skylake SP";  procSig = "0x00050654"; ucodeRevFixed = "0x02000043"; ucodeRevSightings = "0x0200003A"}
	    [PSCustomObject]@{Name = "Kaby Lake H/S/X";  procSig = "0x000906e9"; ucodeRevFixed = "0x00000084"; ucodeRevSightings = "0x0000007C"}
	    [PSCustomObject]@{Name = "Zen EPYC";  procSig = "0x00800f12"; ucodeRevFixed = "0x08001227"; ucodeRevSightings = ""}
    )

    # Remote SSH commands for retrieving current ESXi host microcode version
    $plinkoptions = "-ssh -pw $ESXiPassword"
    $cmd = "vsish -e cat /hardware/cpu/cpuList/0 | grep `'Current Revision:`'"
    $remoteCommand = '"' + $cmd + '"'

    $results = @()
    foreach ($vmhost in $vmhosts | Sort-Object -Property Name) {
        $vmhostDisplayName = $vmhost.Name
        $cpuModelName = $($vmhost.Summary.Hardware.CpuModel -replace '\s+', ' ')

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
        $cpuidEAX = ($vmhost.Hardware.CpuFeature | Where-Object {$_.Level -eq 1}).Eax -Replace ":",""
        $cpuidEAXbyte = $cpuidEAX -Split "(?<=\G\d{8})(?=\d{8})"
        $cpuidEAXnibble = $cpuidEAX -Split "(?<=\G\d{4})(?=\d{4})"

        $cpuSignature = "0x" + $(($cpuidEAXbyte | Foreach-Object {[System.Convert]::ToByte($_, 2)} | Foreach-Object {$_.ToString("X2")}) -Join "")

        # https://software.intel.com/en-us/articles/intel-architecture-and-processor-identification-with-cpuid-model-and-family-numbers
        $ExtendedFamily = [System.Convert]::ToInt32($($cpuidEAXnibble[1] + $cpuidEAXnibble[2]), 2)
        $Family = [System.Convert]::ToInt32($cpuidEAXnibble[5], 2)

        # output now in decimal, not hex!
        $cpuFamily = $ExtendedFamily + $Family
        $cpuModel = [System.Convert]::ToByte($($cpuidEAXnibble[3] + $cpuidEAXnibble[6]), 2)
        $cpuStepping = [System.Convert]::ToByte($cpuidEAXnibble[7], 2)

        # check and compare ucode 
        $intelSighting = $false
        $goodUcode = $false

        foreach ($cpu in $procSigUcodeTable) {
            if ($cpuSignature -eq $cpu.procSig) {
                if ($microcodeVersion -eq $cpu.ucodeRevSightings) {
                    $intelSighting = $true
                } elseif ($microcodeVersion -as [int] -ge $cpu.ucodeRevFixed -as [int]) {
                    $goodUcode = $true
                }
            }
        }

        $tmp = [pscustomobject] @{
            VMHost = $vmhostDisplayName;
            "CPU Model Name" = $cpuModelName;
            Family = $cpuFamily;
            Model = $cpuModel;
            Stepping = $cpuStepping;
            Microcode = $microcodeVersion;
            procSig = $cpuSignature;
            IBRSPresent = $IBRSPass;
            IBPBPresent = $IBPBPass;
            STIBPPresent = $STIBPPass;
            HypervisorAssistedGuestAffected = $vmhostAffected;
            "Good Microcode" = $goodUcode;
            IntelSighting = $intelSighting;
        }
        $results+=$tmp
    }
    $results | FT *
}
