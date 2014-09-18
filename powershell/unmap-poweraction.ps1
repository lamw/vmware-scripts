# William Lam
# www.virtuallyghetto
# Script to issue UNMAP command on specified VMFS datastore

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