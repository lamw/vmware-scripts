Function Add-VMGuestInfo {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.williamlam.com
     Twitter:       @lamw
	===========================================================================
    .SYNOPSIS
        Function to add Guestinfo properties to a VM
    .EXAMPLE
        $newGuestProperties = @{
            "guestinfo.foo1" = "bar1"
            "guestinfo.foo2" = "bar2"
            "guestinfo.foo3" = "bar3"
        }

        Add-VMGuestInfo -vmname DeployVM -vmguestinfo $newGuestProperties
#>
    param(
        [Parameter(Mandatory=$true)][String]$vmname,
        [Parameter(Mandatory=$true)][Hashtable]$vmguestinfo
    )

    $vm = Get-VM -Name $vmname
    $currentVMExtraConfig = $vm.ExtensionData.config.ExtraConfig

    $spec = New-Object VMware.Vim.VirtualMachineConfigSpec

    $vmguestinfo.GetEnumerator() | Foreach-Object {
        $optionValue = New-Object VMware.Vim.OptionValue
        $optionValue.Key = $_.Key
        $optionValue.Value = $_.Value
        $currentVMExtraConfig += $optionValue
    }
    $spec.ExtraConfig = $currentVMExtraConfig
    $vm.ExtensionData.ReconfigVM($spec)
}

Function Remove-VMGuestInfo {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.williamlam.com
     Twitter:       @lamw
	===========================================================================
    .SYNOPSIS
        Function to remove Guestinfo properties to a VM
    .EXAMPLE
        $newGuestProperties = @{
            "guestinfo.foo1" = "bar1"
            "guestinfo.foo2" = "bar2"
            "guestinfo.foo3" = "bar3"
        }

        Remove-VMGuestInfo -vmname DeployVM -vmguestinfo $newGuestProperties
#>
    param(
        [Parameter(Mandatory=$true)][String]$vmname,
        [Parameter(Mandatory=$true)][Hashtable]$vmguestinfo
    )

    $vm = Get-VM -Name $vmname
    $currentVMExtraConfig = $vm.ExtensionData.config.ExtraConfig

    $updatedVMExtraConfig = @()
    foreach ($vmExtraConfig in $currentVMExtraConfig) {
       if(-not ($vmguestinfo.ContainsKey($vmExtraConfig.key))) {
            $updatedVMExtraConfig += $vmExtraConfig
       }
    }
    $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
    $spec.ExtraConfig = $updatedVMExtraConfig
    $vm.ExtensionData.ReconfigVM($spec)
}
