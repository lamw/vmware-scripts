Function Get-PlaceholderVM {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.virtuallyghetto.com
     Twitter:       @lamw
    ===========================================================================
    .DESCRIPTION
        This function retrieves all placeholder VMs that are protected by SRM
#>
	$results = @()
	Foreach ($vm in Get-VM) {
		if($vm.ExtensionData.Summary.Config.ManagedBy.Type -eq "placeholderVm") {
			$tmp = [pscustomobject] @{
				Name = $vm.Name;
				ExtKey = $vm.ExtensionData.Summary.Config.ManagedBy.ExtensionKey;
				Type = $vm.ExtensionData.Summary.Config.ManagedBy.Type
			}
			$results+=$tmp
		}
	}
	$results
}