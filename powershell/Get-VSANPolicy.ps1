<#
.SYNOPSIS  Retrieve the VSAN Policy for a given VM(s) which includes filtering
    of VMs that do not contain a policy (None) or policies in which contains
    Thick Provisioning (e.g Object Space Reservation set to 100)
.NOTES  Author:  William Lam
.NOTES  Site:    www.virtuallyghetto.com
.PARAMETER Vm
  Virtual Machine(s) object to query for VSAN VM Storage Policies
.EXAMPLE
  PS> Get-VM * | Get-VSANPolicy -datastore "vsanDatastore"
  PS> Get-VM * | Get-VSANPolicy -datastore "vsanDatastore" -nopolicy $false -thick $true -details $true
#>

Function Get-VSANPolicy {
    param(
    [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    [VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl[]]$vms,
    [String]$details=$false,
    [String]$datastore,
    [String]$nopolicy=$false,
    [String]$thick=$false
    )

    process {
        foreach ($vm in $vms) {
            # Extract the VSAN UUID for VM Home
            $vm_dir,$vm_vmx = ($vm.ExtensionData.Config.Files.vmPathName).split('/').replace('[','').replace(']','')
            $vmdatastore,$vmhome_obj_uuid = ($vm_dir).split(' ')

            # Process only if we have a match on the specified datastore
            if($vmdatastore -eq $datastore) {
                $cmmds_queries = @()
                $disks_to_uuid_mapping = @{}
                $disks_to_uuid_mapping[$vmhome_obj_uuid] = "VM Home"

                # Create query object for VM home
                $vmhome_query = New-Object VMware.vim.HostVsanInternalSystemCmmdsQuery
                $vmhome_query.Type = "POLICY"
                $vmhome_query.Uuid = $vmhome_obj_uuid

                # Add the VM Home query object to overall cmmds query spec
                $cmmds_queries += $vmhome_query

                # Go through all VMDKs & build query object for each disk
                $devices = $vm.ExtensionData.Config.Hardware.Device
                foreach ($device in $devices) {
                    if($device -is [VMware.Vim.VirtualDisk]) {
                        if($device.backing.backingObjectId) {
                            $disks_to_uuid_mapping[$device.backing.backingObjectId] = $device.deviceInfo.label
                            $disk_query = New-Object VMware.vim.HostVsanInternalSystemCmmdsQuery
                            $disk_query.Type = "POLICY"
                            $disk_query.Uuid = $device.backing.backingObjectId
                            $cmmds_queries += $disk_query
                        }
                    }
                }

                # Access VSAN Internal System to issue the Cmmds query
                $vsanIntSys = Get-View ((Get-View $vm.ExtensionData.Runtime.Host -Property Name, ConfigManager.vsanInternalSystem).ConfigManager.vsanInternalSystem)
                $results = $vsanIntSys.QueryCmmds($cmmds_queries)

                $printed = @{}
                $json = $results | ConvertFrom-Json
                foreach ($j in $json.result) {
                    $storagepolicy_id = $j.content.spbmProfileId

                    # If there's no spbmProfileID, it means there's
                    # no VSAN VM Storage Policy assigned
                    # possibly deployed from vSphere C# Client
                    if($storagepolicy_id -eq $null -and $nopolicy -eq $true) {
                        $object_type = $disks_to_uuid_mapping[$j.uuid]
                        $policy = $j.content

                        # quick/dirty way to only print VM name once
                        if($printed[$vm.name] -eq $null -and $thick -eq $false) {
                            $printed[$vm.name] = "1"
                            Write-Host "`n"$vm.Name
                        }

                        if($details -eq $true -and $thick -eq $false) {
                           Write-Host "$object_type `t` $policy"
                        } elseIf($details -eq $false -and $thick -eq $false) {
                           Write-Host "$object_type `t` None"
                        } else {
                            # Ignore VM Home which will always be thick provisioned
                            if($object_type -ne "VM Home") {
                                if($policy.proportionalCapacity -eq 100) {
                                    Write-Host "`n"$vm.Name
                                    if($details -eq $true) {
                                        Write-Host "$object_type `t` $policy"
                                    } else {
                                        Write-Host "$object_type"
                                    }
                                }
                            }
                        }
                    } elseIf($storagepolicy_id -ne $null -and $nopolicy -eq $false) {
                        $object_type = $disks_to_uuid_mapping[$j.uuid]
                        $policy = $j.content

                        # quick/dirty way to only print VM name once
                        if($printed[$vm.name] -eq $null -and $thick -eq $false) {
                            $printed[$vm.name] = "1"
                            Write-Host "`n"$vm.Name
                        }

                        # Convert the VM Storage Policy ID to human readable name
                        $vsan_policy_name = Get-SpbmStoragePolicy -Id $storagepolicy_id

                        if($details -eq $true -and $thick -eq $false) {
                            Write-Host "$object_type `t` $vsan_policy_name `t` $policy"
                        } elseIf($details -eq $false -and $thick -eq $false) {
                            if($vsan_policy_name -eq $null) {
                                Write-Host "$object_type `t` None"
                            } else {
                                Write-Host "$object_type `t` $vsan_policy_name"
                            }
                        } else {
                            # Ignore VM Home which will always be thick provisioned
                            if($object_type -ne "VM Home") {
                                if($policy.proportionalCapacity -eq 100) {
                                    if($printed[$vm.name] -eq $null) {
                                        $printed[$vm.name] = "1"
                                        Write-Host "`n"$vm.Name
                                    }
                                    if($details -eq $true) {
                                        Write-Host "$object_type `t` $policy"
                                    } else {
                                        Write-Host "$object_type"
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

Connect-VIServer -Server 192.168.1.51 -User administrator@vghetto.local -password VMware1! | Out-Null

Get-VM "Photon-Deployed-From-WebClient*" | Get-VSANPolicy -datastore "vsanDatastore" -thick $true -details $true

Disconnect-VIServer * -Confirm:$false
