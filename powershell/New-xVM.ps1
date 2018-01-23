function New-xVM {
    <#  .Description
        Perform a Cross vCenter Clone Operation across two different vCenter Servers which can either be part of the same or different SSO Domain. Requires that current PowerCLI session has connections (via Connect-VIServer) to both source and destination vCenters

        .SYNOPSIS
        Cross vCenter Clone Operation across two different vCenter Servers

        .NOTES
        Author:  William Lam
        Site:    www.virtuallyghetto.com
        Reference:  Blog: http://www.virtuallyghetto.com/2018/01/cross-vcenter-clone-with-vsphere-6-0.html
        
        Updates added Jan 2018 by Matt Boren:
        - improve ease of use:  can get going with as few as four (4) parameters to function, now, vs. a dozen or more (by gleaning info from the values of the few mandatory parameters, and reduction in overall parameter count)
        - use approved verb for function name
        - add -TrustAllCert Switch parameter to give user option as to whether they want to disable SSL certificate checking, instead of disabling checking regardless
        - take VM from pipeline
        - default to source VM name for dest VM name if no dest VM name specified
        - simplify cluster/resourcepool parameters: remove need for -Cluster, and set default value for ResourcePool, so as to reduce number of parameters needed
        - simplify specifying destination vCenter -- glean this info from the -VMHost object, instead of requiring user to additionally specify the name of the destination vCenter
        - simplify Datacenter parameter (remove it):  glean this info from the -VMHost object, too 
        - add pipeline support to take pertinent values from pipeline (SourceVM)
        - optimize array creation code (just assign collection of values to array variable, instead of potentially more resource-expensive array concatenation (which actually create a new, 1-item larger array for every item addition))
        - get items for credential for ServiceLocatorNamePassword from destination vCenter connection object (Client.Config)
        - improve new-object creation for use in CloneVM task (creation of fewer additional interim variables, clean up overall syntax)
        - correct logic around upper-casing the vC UUID value (was reversed)
        - improve snapshot selection (limit scope to source VM, instead of "get snapshot by name in all of source vC", which may return multiple snapshots)
        - return a Task object, so that user can update task to track progress (via their own Get-Task calls)
        - sort out variable naming in function (had issues where global-scope variables were used inside of the function instead of the corresponding function parameters, like $destVCConn was being used instead of the parameter $destvc)
        - add -WhatIf support
        - complete the comment-based help, so that Get-Help <cmdlet> will return fully useful help (with examples and whatnot), as expected
        Ideas for other updates:
        - add support for specifying destination datastorecluster
        - add support for cloning template
        - take objects for values for additional parameters (already did -SourceVM and -VMHost), for increased precision/accuracy (user can pass the source/destination objects directly instead of dealing with "by string", which might introduce issue due to duplicate names, etc.)
            - taking destination VPGs by object will allow for removal of -switchtype parameter, too
        - remove additional param for UppercaseUuid and just uppercase the vCenter UUID for the operation for success by default, instead of providing possiblity for failure

        .Example
        Get-VM myVM -Server $mySourceVC | New-xVM -VMHost (Get-VMHost mydesthost0.dom.com -Server myDestVCenter.dom.com) -Datastore destDstore01 -VMNetwork myDestVPG0
        Clone VM "myVM" to the vCenter of the given destination VMHost. Will name the new VM the same as the source, placing it on the given VMHost and datastore, and in the default "Resources" resource pool in the destination VMHost's parent cluster. This also takes the default for destination vSwitch type of "VDS".

        .Example
        Get-VM myVM2 -Server $mySourceVC | New-xVM -VMHost (Get-VMHost mydesthost2.dom.com -Server myDestVCenter.dom.com) -Datastore destDstore02 -DestinationVMName myNewVM -VMNetwork myDestVPG1, myDestVPG2 -PowerOn:$true -TrustAllCert
        Clone VM to the vCenter of the given destination VMHost. Will use the new VM name, placing it on the given VMHost and datastore, and in the default "Resources" resource pool in the destination VMHost's parent cluster. This will trust SSL certificates involved (useful for when self-signed certs are in use, say, in a test environment). This also takes the default for destination vSwitch type of "VDS", connects the new VM's networks adapters to the specified VPGs, and powers on the new VM.

        .Outputs
        VMware.VimAutomation.ViCore.Impl.V1.Task.TaskImpl of the Clone task. This Task object "lives" in the _source_ vCenter task list.
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([VMware.VimAutomation.ViCore.Impl.V1.Task.TaskImpl])]
    param(
        ## The source VM object to be cloned to destination vCenter. The "Source vCenter" property will be gleaned from this object
        [parameter(Mandatory=$true, ValueFromPipeline=$true)][VMware.VimAutomation.Types.VirtualMachine]$SourceVM,

        ## Name to use for new VM created in destination vCenter. If not specified, will use name of source VM
        [Alias("destvmname")][String]$DestinationVMName,

        ## The VMHost object from the destination vCenter on which to create the new VM
        [parameter(Mandatory=$true)][VMware.VimAutomation.Types.VMHost]$VMHost,

        ## Name of the destination datastore on which to create the new VM
        [parameter(Mandatory=$true)][String]$Datastore,

        ## Name of the VM inventory folder in the destination vCenter in which to put the new VM. If not specified, will default to the top-level VM folder in the destination datacenter
        [String]$FolderName = "VM",

        ## Name of the destination resource pool to use in the destination cluster. If none specified, will use the default "Resources" resource pool for the parent cluster of the destination VMHost
        [String]$ResourcePool = "Resources",

        ## Type of vSwitch where target VM network(s) reside on destination VMHost. One of "VDS", "VSS". Defaults to "VDS"
        [ValidateSet("VDS", "VSS")][String]$switchtype = "VDS",

        ## Name(s) of VPG(s) to which to connect new VM's network adapter(s)
        [String]$vmnetworks,

        ## Optional: Name of snapshot on source VM from which to clone the new VM, if any
        [String]$SnapshotName,

        ## Power-on the new destination VM after creation? By default, new VM will remain powered off
        [Boolean]$poweron,

        ## Convert the vCenter UUID to uppercase for when performing cross vCenter operation? Some vCenters seemingly require the UUID be in uppercase
        [Boolean]$UppercaseUuid,

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
        ## get the connection object for the destination vCenter server
        $oDestinationVIServer = $global:DefaultVIServers | Where-Object {$_.Name -eq $VMHost.Client.Config.Server}
        # In the next few lines, retrieve destination VC SSL Thumbprint
        $strDestinationVCUrl = "https://$($oDestinationVIServer.Name)"
        # Need to do simple GET connection for this method to work
        Invoke-RestMethod -Uri $strDestinationVCUrl -Method Get | Out-Null
        $endpoint_request = [System.Net.Webrequest]::Create($strDestinationVCUrl)
        # Get Thumbprint + add colons for a valid Thumbprint
        $destVCThumbprint = ($endpoint_request.ServicePoint.Certificate.GetCertHashString()) -replace '(..(?!$))','$1:'

        # View object for source VM to clone
        $vm_view = $SourceVM.ExtensionData
        ## source vCenter info (name)
        $strSourceVCenter = $SourceVM.Client.Config.Server

        ## Get destination inventory items
        # Dest Datastore
        $oDestinationDatastore = $VMHost | Get-Datastore -Name $datastore
        # Dest VM Folder
        $oDestinationFolder = $VMHost | Get-Datacenter | Get-Folder -Name $FolderName
        # Dest ResourcePool
        $oDestinationResourcePool = $VMHost | Get-Cluster | Get-ResourcePool -Name $ResourcePool
        ## name to use for destination VM
        $strDestinationVMName = if ($PSBoundParameters.ContainsKey("DestinationVMName")) {$DestinationVMName} else {$SourceVM.Name}
        # Snapshot to clone from, if any
        if ($PSBoundParameters.ContainsKey("SnapshotName")) {$oSourceSnapshot = $SourceVM | Get-Snapshot -Name $snapshotname}

        # Clone Spec
        $spec = New-Object -Type VMware.Vim.VirtualMachineCloneSpec -Property @{
            PowerOn = $poweron
            Template = $false
        } ## end New-Object

        $locationSpec = New-Object -Type VMware.Vim.VirtualMachineRelocateSpec -Property @{
            datastore = $oDestinationDatastore.Id
            host = $VMHost.Id
            pool = $oDestinationResourcePool.Id
            Folder = $oDestinationFolder.Id
            # Service Locator for the destination vCenter Server regardless if its within same SSO Domain or not
            service = New-Object -Type VMware.Vim.ServiceLocator -Property @{
                credential = New-Object -Type VMware.Vim.ServiceLocatorNamePassword -Property @{
                    ## get the username and password for the destination vCenter from the VIServer connection object in the current session
                    username = $oDestinationVIServer.Client.Config.Username
                    password = $oDestinationVIServer.Client.Config.Password
                } ## end New-Object ServiceLocatorNamePassword
                # For some xVC-vMotion, VC's InstanceUUID must be in all caps
                # Haven't figured out why. Hoever, this flag would allow user to toggle (default=false)
                instanceUuid = if ($UppercaseUuid) {$oDestinationVIServer.InstanceUuid.ToUpper()} else {$oDestinationVIServer.InstanceUuid}
                sslThumbprint = $destVCThumbprint
                url = $strDestinationVCUrl
            } ## end New-Object ServiceLocator
        } ## end New-Object VirtualMachineRelocateSpec

        # Find all Ethernet Devices for given VM which we will need to change its network at the destination
        $vmNetworkAdapters = $vm_view.Config.Hardware.Device | Where-Object {$_ -is [VMware.Vim.VirtualEthernetCard]}
        # Create VM spec depending if destination networking
        # is using Distributed Virtual Switch (VDS) or
        # is using Virtual Standard Switch (VSS)
        $count = 0
        if($switchtype -eq "vds") {
            foreach ($vmNetworkAdapter in $vmNetworkAdapters) {
                # New VM Network to assign vNIC
                $vmnetworkname = ($vmnetworks -split ",")[$count]

                # Extract Distributed Portgroup required info
                $dvpg = Get-VDPortgroup -Server $oDestinationVIServer -Name $vmnetworkname
                $vds_uuid = (Get-View $dvpg.ExtensionData.Config.DistributedVirtualSwitch).Uuid
                $dvpg_key = $dvpg.ExtensionData.Config.key

                # Device Change spec for VSS portgroup
                $dev = New-Object VMware.Vim.VirtualDeviceConfigSpec
                $dev.Operation = "edit"
                $dev.Device = $vmNetworkAdapter
                $dev.device.Backing = New-Object -Type VMware.Vim.VirtualEthernetCardDistributedVirtualPortBackingInfo -Property @{
                    port = New-Object -Type VMware.Vim.DistributedVirtualSwitchPortConnection -Property @{
                        switchUuid = $vds_uuid
                        portgroupKey = $dvpg_key
                    } ## end new-object DistributedVirtualSwitchPortConnection
                } ## end new-object VirtualEthernetCardDistributedVirtualPortBackingInfo
                $locationSpec.DeviceChange += $dev
                $count++
            } ## end foreach
        } else {
            foreach ($vmNetworkAdapter in $vmNetworkAdapters) {
                # New VM Network to assign vNIC
                $vmnetworkname = ($vmnetworks -split ",")[$count]

                # Device Change spec for VSS portgroup
                $dev = New-Object VMware.Vim.VirtualDeviceConfigSpec
                $dev.Operation = "edit"
                $dev.Device = $vmNetworkAdapter
                $dev.device.backing = New-Object -Type VMware.Vim.VirtualEthernetCardNetworkBackingInfo -Property @{
                    deviceName = $vmnetworkname
                } ## end new-object VirtualEthernetCardNetworkBackingInfo
                $locationSpec.DeviceChange += $dev
                $count++
            } ## end foreach
        } ## end else

        $spec.Location = $locationSpec

        ## add the source Snapshot info, if any
        if($oSourceSnapshot) {$spec.Snapshot = $oSourceSnapshot.Id}

        $strShouldProcessMsg_Target = "VMHost '$($VMHost.Name)' in destination vCenter '$($oDestinationVIServer.Name)'"
        $strShouldProcessMsg_Action = "Create new VM '$strDestinationVMName' from source VM '$($SourceVM.Name)' from vCenter '$strSourceVCenter'"
        if ($PSCmdlet.ShouldProcess($strShouldProcessMsg_Target, $strShouldProcessMsg_Action)) {
            Write-Verbose -Verbose "Cloning $($SourceVM.Name) from $strSourceVCenter to $($oDestinationVIServer.Name), creating new VM named '$strDestinationVMName'"

            # Issue Cross VC-vMotion, get Task MoRef back
            $task = $vm_view.CloneVM_Task($oDestinationFolder.Id, $strDestinationVMName, $spec)
            ## return the Task object so that the user can track task as desired
            Get-Task -Server $strSourceVCenter -Id $task
        } ## end if
    } ## end process
} ## end function
