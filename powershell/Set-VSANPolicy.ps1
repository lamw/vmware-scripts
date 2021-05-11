<#
.SYNOPSIS  Applies a VSAN VM Storage Policy across a list of Virtual Machines
.NOTES  Author:  William Lam
.NOTES  Site:    www.williamlam.com
.EXAMPLE
  PS> Set-VSANPolicy -listofvms $arrayofvmnames -policy $vsanpolicyname
#>

Function Set-VSANPolicy {
    param(
    [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    [string[]]$listofvms,
    [String]$policy
    )

    $vmstoremediate = @()
    foreach ($vm in $listofvms) {
        $hds = Get-VM $vm | Get-HardDisk
        Write-Host "`nApplying VSAN VM Storage Policy:" $policy "to" $vm "..."
        Set-SpbmEntityConfiguration -Configuration (Get-SpbmEntityConfiguration $hds) -StoragePolicy $policy
    }
}

Connect-VIServer -Server 192.168.1.51 -User administrator@vghetto.local -password VMware1! | Out-Null

# Define list of VMs you wish to remediate and apply VSAN VM Storage Policy
$listofvms = @(
"Photon-Deployed-From-WebClient-Multiple-Disks-1",
"Photon-Deployed-From-WebClient-Multiple-Disks-2"
)

# Name of VSAN VM Storage Policy to apply
$vsanpolicy = "Virtual SAN Default Storage Policy"

Set-VSANPolicy -listofvms $listofvms -policy $vsanpolicy

Disconnect-VIServer * -Confirm:$false
