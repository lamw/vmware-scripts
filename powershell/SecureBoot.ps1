Function Get-SecureBoot {
    <#
    .SYNOPSIS Query Seure Boot setting for a VM in vSphere 6.5
    .NOTES  Author:  William Lam
    .NOTES  Site:    www.williamlam.com
    .PARAMETER Vm
      VM to query Secure Boot setting
    .EXAMPLE
      Get-VM -Name Windows10 | Get-SecureBoot
    #>
    param(
        [Parameter(
            Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)
        ]
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl]$Vm
     )

     $secureBootSetting = if ($vm.ExtensionData.Config.BootOptions.EfiSecureBootEnabled) { "enabled" } else { "disabled" }
     Write-Host "Secure Boot is" $secureBootSetting
}

Function Set-SecureBoot {
    <#
    .SYNOPSIS Enable/Disable Seure Boot setting for a VM in vSphere 6.5
    .NOTES  Author:  William Lam
    .NOTES  Site:    www.williamlam.com
    .PARAMETER Vm
      VM to enable/disable Secure Boot
    .EXAMPLE
      Get-VM -Name Windows10 | Set-SecureBoot -Enabled
    .EXAMPLE
      Get-VM -Name Windows10 | Set-SecureBoot -Disabled
    #>
    param(
        [Parameter(
            Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)
        ]
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl]$Vm,
        [Switch]$Enabled,
        [Switch]$Disabled
     )

    if($Enabled) {
        $secureBootSetting = $true
        $reconfigMessage = "Enabling Secure Boot for $Vm"
    }
    if($Disabled) {
        $secureBootSetting = $false
        $reconfigMessage = "Disabling Secure Boot for $Vm"
    }

    $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
    $bootOptions = New-Object VMware.Vim.VirtualMachineBootOptions
    $bootOptions.EfiSecureBootEnabled = $secureBootSetting
    $spec.BootOptions = $bootOptions
  
    Write-Host "`n$reconfigMessage ..."
    $task = $vm.ExtensionData.ReconfigVM_Task($spec)
    $task1 = Get-Task -Id ("Task-$($task.value)")
    $task1 | Wait-Task | Out-Null
}
