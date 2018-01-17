    <#  .Description
        Perform a Cross vCenter Clone Operation across two different vCenter Servers which can either be part of the same or different SSO Domain

        .SYNOPSIS
        Cross vCenter Clone Operation across two different vCenter Servers


        .NOTES
        Author:  William Lam
        Site:    www.virtuallyghetto.com
        Reference:  Blog: http://www.virtuallyghetto.com/2018/01/cross-vcenter-clone-with-vsphere-6-0.html
        Updates added Jan 2018 by Matt Boren:
        - use approved verb for function name
        - add -TrustAllCert Switch parameter to give user option as to whether they want to disable SSL certificate checking, instead of disabling checking regardless
        - complete the comment-based help, so that Get-Help <cmdlet> will return fully useful help (with examples and whatnot), as expected
        - add pipeline support to take values from pipeline
        - work on parameter sets so that -ResourcePool _or_ -Cluster + -VMHost are used (but, so that user can do one or the other)
        - correct logic around upper-casing the vC UUID value (was reversed)
        - correct variable naming (had issues where global-scope variable were used inside of the function instead of the corresponding parameters, like $destVCConn was being used instead of the parameter $destvc)
        - return a Task object, so that user can update task to track progress (via their own Get-Task calls)
        - optimize array creation code (just assign collection of values to array variable, instead of potentially more resource-expensive array concatenation (which actually create a new, 1-item larger array for every item addition))
        - remove unnecessary -Cluster parameter, since -VMHost is mandatory for clone to different vCenter
        - improve snapshot selection (limit scope to source VM, instead of "get snapshot by name in all of source vC", which may return multiple snapshots)
        - improve new object creation for use in CloneVM task (creation of fewer additional interim variables)
        - get items for credential for ServiceLocatorNamePassword from destination vCenter connection object (Client.Config)
        Ideas for other updates:
        - add support for specifying destination datastorecluster
        - add support for cloning template
    #>

    param(
        # [VMware.VimAutomation.ViCore.Util10.VersionedObjectImpl]$sourcevc, ## get this from SourceVM
        [VMware.VimAutomation.ViCore.Util10.VersionedObjectImpl]$destvc,
        [String]$sourcevmname,  ## Make SourceVM, take object from pipeline, get "source VC from this"
        [String]$destvmname,
        [String]$switchtype,
        #[String]$datacenter,  DETERMINE FROM VMHost
        #[String]$cluster,  DETERMINE FROM VMHost
        [String]$resourcepool,  ## if not specified, get the resource pool of the cluster
        [String]$datastore,
        [parameter(Mandatory=$true)][String]$vmhost,
        [String]$vmnetworks,
        [String]$foldername, ## default to "Discovered virtual machine" or "vm"
        [String]$snapshotname, ## get from VM below, instead of just by name in whole vCenter
        [Boolean]$poweron,
        [Boolean]$uppercaseuuid,
        ## Switch: Trust all SSL certificates, valid or otherwise?  Essentially, "SkipCertificateCheck". Note: this sets this behavior for the whole of the current PowerShell session, not just for this command.
        [Alias("SkipCertificateCheck")][Switch]$TrustAllCert
    )

    begin {
        if ($TrustAllCert) {
            ## if this type is not already present in the current PowerShell session, add it
            if (-not ("IDontCarePolicy" -as [Type])) {
                Add-Type @"
                using System.Net;
                using System.Security.Cryptography.X509Certificates;

                    public class IDontCarePolicy : ICertificatePolicy {
                    public IDontCarePolicy() {}
                    public bool CheckValidationResult(
                        ServicePoint sPoint, X509Certificate cert,
                        WebRequest wRequest, int certProb) {
                        return true;
                    }
                }
"@
            } ## end if
            ## set the CertificatePolicy to essentially skip cert checking by setting the CheckValidationResult() return to always be $true
            [System.Net.ServicePointManager]::CertificatePolicy = New-Object IDontCarePolicy
        } ## end if
    } ## end begin

    process {
        # Retrieve Source VC SSL Thumbprint
        $vcurl = "https://" + $destVC
        # Need to do simple GET connection for this method to work
        Invoke-RestMethod -Uri $VCURL -Method Get | Out-Null
        $endpoint_request = [System.Net.Webrequest]::Create("$vcurl")
        # Get Thumbprint + add colons for a valid Thumbprint
        $destVCThumbprint = ($endpoint_request.ServicePoint.Certificate.GetCertHashString()) -replace '(..(?!$))','$1:'

        # Source VM to clone from
        $vm_view = Get-View (Get-VM -Server $sourcevc -Name $sourcevmname) -Property Config.Hardware.Device

        # Dest Datastore to clone VM to
        $datastore_view = (Get-Datacenter -Server $destVCConn -Name $datacenter | Get-Datastore -Server $destVCConn -Name $datastore)

        # Dest VM Folder to clone VM to
        $folder_view = (Get-Datacenter -Server $destVCConn -Name $datacenter | Get-Folder -Server $destVCConn -Name $foldername)

        # Dest Cluster/ResourcePool to clone VM to
        if ($cluster) {
            $cluster_view = (Get-Datacenter -Server $destVCConn -Name $datacenter | Get-Cluster -Server $destVCConn -Name $cluster)
            $resource = $cluster_view.ExtensionData.resourcePool
        } else {
            $rp_view = (Get-Datacenter -Server $destVCConn -Name $datacenter | Get-ResourcePool -Server $destVCConn -Name $resourcepool)
            $resource = $rp_view.ExtensionData.MoRef
        }

        # Dest ESXi host to clone VM to
        $vmhost_view = (Get-VMHost -Server $destVCConn -Name $vmhost)

        # Find all Etherenet Devices for given VM which
        # we will need to change its network at the destination
        $vmNetworkAdapters = @()
        $devices = $vm_view.Config.Hardware.Device
        foreach ($device in $devices) {
            if($device -is [VMware.Vim.VirtualEthernetCard]) {
                $vmNetworkAdapters += $device
            }
        }

        # Snapshot to clone from
        if($snapshotname) {
            $snapshot = Get-Snapshot -Server $sourcevc -Name $snapshotname
        }

        # Clone Spec
        $spec = New-Object VMware.Vim.VirtualMachineCloneSpec
        $spec.PowerOn = $poweron
        $spec.Template = $false
        $locationSpec = New-Object VMware.Vim.VirtualMachineRelocateSpec

        $locationSpec.datastore = $datastore_view.Id
        $locationSpec.host = $vmhost_view.Id
        $locationSpec.pool = $resource
        $locationSpec.Folder = $folder_view.Id

        # Service Locator for the destination vCenter Server
        # regardless if its within same SSO Domain or not
        $service = New-Object VMware.Vim.ServiceLocator
        $credential = New-Object VMware.Vim.ServiceLocatorNamePassword
        $credential.username = $destVCusername
        $credential.password = $destVCpassword
        $service.credential = $credential
        # For some xVC-vMotion, VC's InstanceUUID must be in all caps
        # Haven't figured out why, but this flag would allow user to toggle (default=false)
        if($uppercaseuuid) {
            $service.instanceUuid = $destVCConn.InstanceUuid
        } else {
            $service.instanceUuid = ($destVCConn.InstanceUuid).ToUpper()
        }
        $service.sslThumbprint = $destVCThumbprint
        $service.url = "https://$destVC"
        $locationSpec.service = $service

        # Create VM spec depending if destination networking
        # is using Distributed Virtual Switch (VDS) or
        # is using Virtual Standard Switch (VSS)
        $count = 0
        if($switchtype -eq "vds") {
            foreach ($vmNetworkAdapter in $vmNetworkAdapters) {
                # New VM Network to assign vNIC
                $vmnetworkname = ($vmnetworks -split ",")[$count]

                # Extract Distributed Portgroup required info
                $dvpg = Get-VDPortgroup -Server $destvc -Name $vmnetworkname
                $vds_uuid = (Get-View $dvpg.ExtensionData.Config.DistributedVirtualSwitch).Uuid
                $dvpg_key = $dvpg.ExtensionData.Config.key

                # Device Change spec for VSS portgroup
                $dev = New-Object VMware.Vim.VirtualDeviceConfigSpec
                $dev.Operation = "edit"
                $dev.Device = $vmNetworkAdapter
                $dev.device.Backing = New-Object VMware.Vim.VirtualEthernetCardDistributedVirtualPortBackingInfo
                $dev.device.backing.port = New-Object VMware.Vim.DistributedVirtualSwitchPortConnection
                $dev.device.backing.port.switchUuid = $vds_uuid
                $dev.device.backing.port.portgroupKey = $dvpg_key
                $locationSpec.DeviceChange += $dev
                $count++
            }
        } else {
            foreach ($vmNetworkAdapter in $vmNetworkAdapters) {
                # New VM Network to assign vNIC
                $vmnetworkname = ($vmnetworks -split ",")[$count]

                # Device Change spec for VSS portgroup
                $dev = New-Object VMware.Vim.VirtualDeviceConfigSpec
                $dev.Operation = "edit"
                $dev.Device = $vmNetworkAdapter
                $dev.device.backing = New-Object VMware.Vim.VirtualEthernetCardNetworkBackingInfo
                $dev.device.backing.deviceName = $vmnetworkname
                $locationSpec.DeviceChange += $dev
                $count++
            }
        }

        $spec.Location = $locationSpec

        if($snapshot) {
            $spec.Snapshot = $snapshot.Id
        }

        Write-Host "`nCloning $sourcevmname from $sourceVC to $destVC ...`n"

        # Issue Cross VC-vMotion
        $task = $vm_view.CloneVM_Task($folder_view.Id,$destvmname,$spec)
        $task1 = Get-Task -Server $sourceVCConn -Id ("Task-$($task.value)")
    } ## end process
# } ## end function

<#
# Variables that must be defined (left over from old development)

$sourcevmname = "PhotonOS-02"
$destvmname= "PhotonOS-02-Clone"
$sourceVC = "vcenter65-1.primp-industries.com"
$sourceVCUsername = "administrator@vsphere.local"
$sourceVCPassword = "VMware1!"
$destVC = "vcenter65-3.primp-industries.com"
$destVCUsername = "administrator@vsphere.local"
$destVCpassword = "VMware1!"
$datastorename = "vsanDatastore"
$datacenter = "Datacenter-SiteB"
$cluster = "Santa-Barbara"
$resourcepool = "MyRP" # cluster property not needed if rp is used
$vmhostname = "vesxi65-4.primp-industries.com"
$vmnetworkname = "VM Network"
$foldername = "Discovered virtual machine"
$switchtype = "vss"
$poweron = $false
$snapshotname = "pristine"
$UppercaseUUID = $true

# Connect to Source/Destination vCenter Server
$sourceVCConn = Connect-VIServer -Server $sourceVC -user $sourceVCUsername -password $sourceVCPassword
$destVCConn = Connect-VIServer -Server $destVC -user $destVCUsername -password $destVCpassword

xNew-VM -sourcevc $sourceVCConn -destvc $destVCConn -sourcevmname $sourcevmname -destvmname `
    $destvmname -switchtype $switchtype -datacenter $datacenter -cluster $cluster -vmhost `
    $vmhostname -datastore $datastorename -vmnetwork  $vmnetworkname -foldername `
    $foldername -poweron $poweron -uppercaseuuid $UppercaseUUID

# Disconnect from Source/Destination VC
Disconnect-VIServer -Server $sourceVCConn -Confirm:$false
Disconnect-VIServer -Server $destVCConn -Confirm:$false
#>