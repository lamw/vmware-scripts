# Author: William Lam
# Website: www.virtuallyghetto
# Product: VMware vSphere
# Description: Script to issue UNMAP command on specified VMFS datastore
# Reference: http://www.virtuallyghetto.com/2014/09/want-to-issue-a-vaai-unmap-operation-using-the-vsphere-web-client.html

param
(
   [Parameter(Mandatory=$true)]
   [VMware.VimAutomation.ViCore.Types.V1.DatastoreManagement.Datastore]
   $datastore,
   [Parameter(Mandatory=$true)]
   [string]
   $numofvmfsblocks
);

# Retrieve a random ESXi host which has access to the selected Datastore
$esxi = (Get-View (($datastore.ExtensionData.Host | Get-Random).key) -Property Name).name

# Retrieve ESXCLI instance from the selected ESXi host
$esxcli = Get-EsxCli -Server $global:DefaultVIServer -VMHost $esxi

# Reclaim based on the number of blocks specified by user
$esxcli.storage.vmfs.unmap($numofvmfsblocks,$datastore,$null)
