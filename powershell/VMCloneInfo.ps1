<#PSScriptInfo
.VERSION 1.0.0
.GUID 419ab591-3184-4e1a-a1f5-563d386c6f9b
.AUTHOR William Lam
.COMPANYNAME VMware
.COPYRIGHT Copyright 2021, William Lam
.TAGS VMware Clone
.LICENSEURI
.PROJECTURI https://github.com/lamw/vghetto-scripts/blob/master/powershell/VMCloneInfo.ps1
.ICONURI https://blogs.vmware.com/virtualblocks/files/2018/10/PowerCLI.png
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
    1.0.0 - Initial Release
.PRIVATEDATA
.DESCRIPTION This function retrieves cloning information about a given VM
#>

Function Get-VMCloneInfo {
    <#
        .NOTES
        ===========================================================================
        Created by:    William Lam
        Organization:  VMware
        Blog:          www.williamlam.com
        Twitter:       @lamw
        ===========================================================================
        .PARAMETER VMName
            The name of a VM to retrieve cloning information
        .EXAMPLE
            Get-VMCloneInfo -VMName "SourceVM"
            Get-VMCloneInfo -VMName "Full-Clone-VM"
            Get-VMCloneInfo -VMName "Linked-Clone-VM"
            Get-VMCloneInfo -VMName "Instant-Clone-VM"
    #>
    param(
        [Parameter(Mandatory = $true)][String]$VMName
    )

    $clonedVM = Get-VM $VMName
    $clonedEvent = Get-VIEvent -Types Info -Entity $clonedVM | Where {($_.Vm.Name -eq $VMName) -and ($_.getType().name -eq "VmClonedEvent" -or $_.EventTypeId -eq "com.vmware.vc.VmInstantClonedEvent" -or $_.getType().name -eq "VmDeployedEvent")} | select -First 1

    if($clonedEvent) {
        # Instant Clone
        if($clonedEvent.EventTypeId -match "com.vmware.vc.VmInstantClonedEvent") {
            $CloneType = "Instant"
            $SourceVM = $clonedEvent.Arguments[0].value
        # Full or Linked
        } else {
            # Full Clone from either VM Template or Content Library VMTX
            if($clonedEvent.getType().Name -eq "VmDeployedEvent") {
                $CloneType = "Full"
                $SourceVM = $clonedEvent.SrcTemplate.Name
            # Standard Full or Linked Clone
            } else {
                # Linked Clone VMs seems to have BackingObjectId defined in main descriptor file
                $backingObjectFiles = $clonedVM.ExtensionData.LayoutEx.File | where {$_.Type -eq "diskDescriptor" -and $_.BackingObjectId -ne $null}

                if($backingObjectFiles) {
                    $CloneType = "Linked"
                } else {
                    $CloneType = "Full"
                }
                $SourceVM = $clonedEvent.SourceVM.Name;
            }
        }

        $results = [pscustomobject] @{
            Type = $CloneType;
            Source = $SourceVM;
            Date = $clonedEvent.CreatedTime
            User = $clonedEvent.UserName
        }

        $results
    } else {
        Write-Host "Unable to find any cloning information for ${VMName}, VM may not have been cloned or vCenter Events have rolled over"
    }
}

