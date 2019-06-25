Function Get-ESXiBootDevice {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.virtuallyghetto.com
     Twitter:       @lamw
        ===========================================================================
    .DESCRIPTION
        This function identifies how an ESXi host was booted up along with its boot
        device (if applicable). This supports both local installation to Auto Deploy as
        well as Boot from SAN.
    .PARAMETER VMHostname
        The name of an individual ESXi host managed by vCenter Server
    .EXAMPLE
        Get-ESXiBootDevice
    .EXAMPLE
        Get-ESXiBootDevice -VMHostname esxi-01
#>
    param(
        [Parameter(Mandatory=$false)][String]$VMHostname
    )

    if($VMHostname) {
        $vmhosts = Get-VMhost -Name $VMHostname
    } else {
        $vmhosts = Get-VMHost
    }

    $results = @()
    foreach ($vmhost in ($vmhosts | Sort-Object -Property Name)) {
        $esxcli = Get-EsxCli -V2 -VMHost $vmhost
        $bootDetails = $esxcli.system.boot.device.get.Invoke()

        # Check to see if ESXi booted over the network
        $networkBoot = $false
        if($bootDetails.BootNIC) {
            $networkBoot = $true
            $bootDevice = $bootDetails.BootNIC
        } elseif ($bootDetails.StatelessBootNIC) {
            $networkBoot = $true
            $bootDevice = $bootDetails.StatelessBootNIC
        }

        # If ESXi booted over network, check to see if deployment
        # is Stateless, Stateless w/Caching or Stateful
        if($networkBoot) {
            $option = $esxcli.system.settings.advanced.list.CreateArgs()
            $option.option = "/UserVars/ImageCachedSystem"
            try {
                $optionValue = $esxcli.system.settings.advanced.list.Invoke($option)
                $bootType = $optionValue.StringValue
            } catch {
                $bootType = "stateless"
            }
        }

        # Loop through all storage devices to identify boot device
        $devices = $esxcli.storage.core.device.list.Invoke()
        $foundBootDevice = $false
        foreach ($device in $devices) {
            if($device.IsBootDevice -eq $true) {
                $foundBootDevice = $true

                if($device.IsLocal -eq $true -and $networkBoot -and $bootType -ne "stateful") {
                    $bootType = "stateless caching"
                } elseif($device.IsLocal -eq $true -and $networkBoot -eq $false) {
                    $bootType = "local"
                } elseif($device.IsLocal -eq $false -and $networkBoot -eq $false) {
                    $bootType = "remote"
                }

                $bootDevice = $device.Device
                $bootModel = $device.Model
                $bootVendor = $device.VEndor
                $bootSize = $device.Size
                $bootIsSAS = $device.IsSAS
                $bootIsSSD = $device.IsSSD
                $bootIsUSB = $device.IsUSB
            }
        }

        # Pure Stateless (e.g. No USB or Disk for boot)
        if($networkBoot-and $foundBootDevice -eq $false) {
            $bootModel = "N/A"
            $bootVendor = "N/A"
            $bootSize = "N/A"
            $bootIsSAS = "N/A"
            $bootIsSSD = "N/A"
            $bootIsUSB = "N/A"
        }

        $tmp = [pscustomobject] @{
            Host = $vmhost.Name;
            Device = $bootDevice;
            BootType = $bootType;
            Vendor = $bootVendor;
            Model = $bootModel;
            SizeMB = $bootSize;
            IsSAS = $bootIsSAS;
            IsSSD = $bootIsSSD;
            IsUSB = $bootIsUSB;
        }
        $results+=$tmp
    }
    $results | FT -AutoSize
}
