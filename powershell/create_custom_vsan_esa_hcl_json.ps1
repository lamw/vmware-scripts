# Author: William Lam
# Description: Dynamically generate custom vSAN ESA HCL JSON file connected to standalone ESXi host

$vmhost = Get-VMHost

$supportedESXiReleases = @("ESXi 8.0 U2")

Write-Host -ForegroundColor Green "`nCollecting SSD information from ESXi host ${vmhost} ... "

$imageManager = Get-View ($Vmhost.ExtensionData.ConfigManager.ImageConfigManager)
$vibs = $imageManager.fetchSoftwarePackages()

$storageDevices = $vmhost.ExtensionData.Config.StorageDevice.scsiTopology.Adapter
$storageAdapters = $vmhost.ExtensionData.Config.StorageDevice.hostBusAdapter
$devices = $vmhost.ExtensionData.Config.StorageDevice.scsiLun
$pciDevices = $vmhost.ExtensionData.Hardware.PciDevice

$ctrResults = @()
$ssdResults = @()
$seen = @{}
foreach ($storageDevice in $storageDevices) {
    $targets = $storageDevice.target
    if($targets -ne $null) {
        foreach ($target in $targets) {
            foreach ($ScsiLun in $target.Lun.ScsiLun) {
                $device = $devices | where {$_.Key -eq $ScsiLun}
                $storageAdapter = $storageAdapters | where {$_.Key -eq $storageDevice.Adapter}
                $pciDevice = $pciDevices | where {$_.Id -eq $storageAdapter.Pci}

                # Convert from Dec to Hex
                $vid = ('{0:x4}' -f $pciDevice.VendorId).ToLower()
                $did = ('{0:x4}' -f $pciDevice.DeviceId).ToLower()
                $svid = ('{0:x4}' -f $pciDevice.SubVendorId).ToLower()
                $ssid = ('{0:x4}' -f $pciDevice.SubDeviceId).ToLower()
                $combined = "${vid}:${did}:${svid}:${ssid}"

                if($storageAdapter.Driver -eq "nvme_pcie" -or $storageAdapter.Driver -eq "pvscsi") {
                    switch ($storageAdapter.Driver) {
                        "nvme_pcie" {
                            $controllerType = $storageAdapter.Driver
                            $controllerDriver = ($vibs | where {$_.name -eq "nvme-pcie"}).Version
                        }
                        "pvscsi" {
                            $controllerType = $storageAdapter.Driver
                            $controllerDriver = ($vibs | where {$_.name -eq "pvscsi"}).Version
                        }
                    }

                    $ssdReleases=@{}
                    foreach ($supportedESXiRelease in $supportedESXiReleases) {
                        $tmpObj = [ordered] @{
                            vsanSupport = @( "All Flash:","vSANESA-SingleTier")
                            $controllerType = [ordered] @{
                                $controllerDriver = [ordered] @{
                                    firmwares = @(
                                        [ordered] @{
                                            firmware = $device.Revision
                                            vsanSupport = [ordered] @{
                                                tier = @("AF-Cache", "vSANESA-Singletier")
                                                mode = @("vSAN", "vSAN ESA")
                                            }
                                        }
                                    )
                                    type = "inbox"
                                }
                            }
                        }
                        if(!$ssdReleases[$supportedESXiRelease]) {
                            $ssdReleases.Add($supportedESXiRelease,$tmpObj)
                        }
                    }

                    if($device.DeviceType -eq "disk" -and !$seen[$combined]) {
                        $ssdTmp = [ordered] @{
                            id = [int]$(Get-Random -Minimum 1000 -Maximum 50000).toString()
                            did = $did
                            vid = $vid
                            ssid = $ssid
                            svid = $svid
                            vendor = $device.Vendor
                            model = ($device.Model).trim()
                            devicetype = $device.ApplicationProtocol
                            partnername = $device.Vendor
                            productid = ($device.Model).trim()
                            partnumber = $device.SerialNumber
                            capacity = [Int]((($device.Capacity.BlockSize * $device.Capacity.Block) / 1048576))
                            vcglink = "https://williamlam.com/homelab"
                            releases = $ssdReleases
                            vsanSupport = [ordered] @{
                                mode = @("vSAN", "vSAN ESA")
                                tier = @("vSANESA-Singletier", "AF-Cache")
                            }
                        }

                        $controllerReleases=@{}
                        foreach ($supportedESXiRelease in $supportedESXiReleases) {
                            $tmpObj = [ordered] @{
                                $controllerType = [ordered] @{
                                    $controllerDriver = [ordered] @{
                                        type = "inbox"
                                        queueDepth = $device.QueueDepth
                                        firmwares = @(
                                            [ordered] @{
                                                firmware = $device.Revision
                                                vsanSupport = @( "Hybrid:Pass-Through","All Flash:Pass-Through","vSAN ESA")
                                            }
                                        )
                                    }
                                }
                                vsanSupport = @( "Hybrid:Pass-Through","All Flash:Pass-Through")
                            }
                            if(!$controllerReleases[$supportedESXiRelease]) {
                                $controllerReleases.Add($supportedESXiRelease,$tmpObj)
                            }
                        }

                        $controllerTmp = [ordered] @{
                            id = [int]$(Get-Random -Minimum 1000 -Maximum 50000).toString()
                            releases = $controllerReleases
                        }

                        $ctrResults += $controllerTmp
                        $ssdResults += $ssdTmp
                        $seen[$combined] = "yes"
                    }
                }
            }
        }
    }
}

# Retrieve the latest vSAN HCL jsonUpdatedTime
$results = Invoke-WebRequest -Uri 'https://partnerweb.vmware.com/service/vsan/all.json?lastupdatedtime' -Headers @{'x-vmw-esp-clientid'='vsan-hcl-vcf-2023'}
# Parse out content between '{...}'
$pattern = '\{(.+?)\}'
$matched = ([regex]::Matches($results, $pattern)).Value

if($matched -ne $null) {
    $vsanHclTime = $matched|ConvertFrom-Json
} else {
    Write-Error "Unable to retrieve vSAN HCL jsonUpdatedTime, ensure you have internet connectivity when running this script"
}

$hclObject = [ordered] @{
    timestamp = $vsanHclTime.timestamp
    jsonUpdatedTime = $vsanHclTime.jsonUpdatedTime
    totalCount = $($ssdResults.count + $ctrResults.count)
    supportedReleases = $supportedESXiReleases
    eula = @{}
    data = [ordered] @{
        controller = @($ctrResults)
        ssd = @($ssdResults)
        hdd = @()
    }
}

$dateTimeGenerated = Get-Date -Uformat "%m_%d_%Y_%H_%M_%S"
$outputFileName = "custom_vsan_esa_hcl_${dateTimeGenerated}.json"

Write-Host -ForegroundColor Green "Saving Custom vSAN ESA HCL to ${outputFileName}`n"
$hclObject | ConvertTo-Json -Depth 12 | Out-File -FilePath $outputFileName

