Function Get-MacLearn {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.virtuallyghetto.com
     Twitter:       @lamw
        ===========================================================================
    .DESCRIPTION
        This function retrieves both the legacy security policies as well as the new
        MAC Learning feature and the new security policies which also live under this
        property which was introduced in vSphere 6.7
    .PARAMETER DVPortgroupName
        The name of Distributed Virtual Portgroup(s)
    .EXAMPLE
        Get-MacLearn -DVPortgroupName @("Nested-01-DVPG")
#>
    param(
        [Parameter(Mandatory=$true)][String[]]$DVPortgroupName
    )

    foreach ($dvpgname in $DVPortgroupName) {
        $dvpg = Get-VDPortgroup -Name $dvpgname -ErrorAction SilentlyContinue
        $switchVersion = ($dvpg | Get-VDSwitch).Version
        if($dvpg -and $switchVersion -eq "6.6.0") {
            $securityPolicy = $dvpg.ExtensionData.Config.DefaultPortConfig.SecurityPolicy
            $macMgmtPolicy = $dvpg.ExtensionData.Config.DefaultPortConfig.MacManagementPolicy

            $securityPolicyResults = [pscustomobject] @{
                DVPortgroup = $dvpgname;
                MacLearning = $macMgmtPolicy.MacLearningPolicy.Enabled;
                NewAllowPromiscuous = $macMgmtPolicy.AllowPromiscuous;
                NewForgedTransmits = $macMgmtPolicy.ForgedTransmits;
                NewMacChanges = $macMgmtPolicy.MacChanges;
                Limit = $macMgmtPolicy.MacLearningPolicy.Limit
                LimitPolicy = $macMgmtPolicy.MacLearningPolicy.limitPolicy
                LegacyAllowPromiscuous = $securityPolicy.AllowPromiscuous.Value;
                LegacyForgedTransmits = $securityPolicy.ForgedTransmits.Value;
                LegacyMacChanges = $securityPolicy.MacChanges.Value;
            }
            $securityPolicyResults
        } else {
            Write-Host -ForegroundColor Red "Unable to find DVPortgroup $dvpgname or VDS is not running 6.6.0"
            break
        }
    }
}

Function Set-MacLearn {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.virtuallyghetto.com
     Twitter:       @lamw
        ===========================================================================
    .DESCRIPTION
        This function allows you to manage the new MAC Learning capablitites in
        vSphere 6.7 along with the updated security policies.
    .PARAMETER DVPortgroupName
        The name of Distributed Virtual Portgroup(s)
    .PARAMETER EnableMacLearn
        Boolean to enable/disable MAC Learn
    .PARAMETER EnablePromiscuous
        Boolean to enable/disable the new Prom. Mode property
    .PARAMETER EnableForgedTransmit
        Boolean to enable/disable the Forged Transmit property
    .PARAMETER EnableMacChange
        Boolean to enable/disable the MAC Address change property
    .PARAMETER AllowUnicastFlooding
        Boolean to enable/disable Unicast Flooding (Default $true)
    .PARAMETER Limit
        Define the maximum number of learned MAC Address, maximum is 4096 (default 4096)
    .PARAMETER LimitPolicy
        Define the policy (DROP/ALLOW) when max learned MAC Address limit is reached (default DROP)
    .EXAMPLE
        Set-MacLearn -DVPortgroupName @("Nested-01-DVPG") -EnableMacLearn $true -EnablePromiscuous $false -EnableForgedTransmit $true -EnableMacChange $false
#>
    param(
        [Parameter(Mandatory=$true)][String[]]$DVPortgroupName,
        [Parameter(Mandatory=$true)][Boolean]$EnableMacLearn,
        [Parameter(Mandatory=$true)][Boolean]$EnablePromiscuous,
        [Parameter(Mandatory=$true)][Boolean]$EnableForgedTransmit,
        [Parameter(Mandatory=$true)][Boolean]$EnableMacChange,
        [Parameter(Mandatory=$false)][Boolean]$AllowUnicastFlooding=$true,
        [Parameter(Mandatory=$false)][Int]$Limit=4096,
        [Parameter(Mandatory=$false)][String]$LimitPolicy="DROP"
    )

    foreach ($dvpgname in $DVPortgroupName) {
        $dvpg = Get-VDPortgroup -Name $dvpgname -ErrorAction SilentlyContinue
        $switchVersion = ($dvpg | Get-VDSwitch).Version
        if($dvpg -and $switchVersion -eq "6.6.0") {
            $originalSecurityPolicy = $dvpg.ExtensionData.Config.DefaultPortConfig.SecurityPolicy

            $spec = New-Object VMware.Vim.DVPortgroupConfigSpec
            $dvPortSetting = New-Object VMware.Vim.VMwareDVSPortSetting
            $macMmgtSetting = New-Object VMware.Vim.DVSMacManagementPolicy
            $macLearnSetting = New-Object VMware.Vim.DVSMacLearningPolicy
            $macMmgtSetting.MacLearningPolicy = $macLearnSetting
            $dvPortSetting.MacManagementPolicy = $macMmgtSetting
            $spec.DefaultPortConfig = $dvPortSetting
            $spec.ConfigVersion = $dvpg.ExtensionData.Config.ConfigVersion

            if($EnableMacLearn) {
                $macMmgtSetting.AllowPromiscuous = $EnablePromiscuous
                $macMmgtSetting.ForgedTransmits = $EnableForgedTransmit
                $macMmgtSetting.MacChanges = $EnableMacChange
                $macLearnSetting.Enabled = $EnableMacLearn
                $macLearnSetting.AllowUnicastFlooding = $AllowUnicastFlooding
                $macLearnSetting.LimitPolicy = $LimitPolicy
                $macLearnsetting.Limit = $Limit

                Write-Host "Enabling MAC Learning on DVPortgroup: $dvpgname ..."
                $task = $dvpg.ExtensionData.ReconfigureDVPortgroup_Task($spec)
                $task1 = Get-Task -Id ("Task-$($task.value)")
                $task1 | Wait-Task | Out-Null
            } else {
                $macMmgtSetting.AllowPromiscuous = $false
                $macMmgtSetting.ForgedTransmits = $false
                $macMmgtSetting.MacChanges = $false
                $macLearnSetting.Enabled = $false

                Write-Host "Disabling MAC Learning on DVPortgroup: $dvpgname ..."
                $task = $dvpg.ExtensionData.ReconfigureDVPortgroup_Task($spec)
                $task1 = Get-Task -Id ("Task-$($task.value)")
                $task1 | Wait-Task | Out-Null
            }
        } else {
            Write-Host -ForegroundColor Red "Unable to find DVPortgroup $dvpgname or VDS is not running 6.6.0"
            break
        }
    }
}