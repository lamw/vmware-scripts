<#
.SYNOPSIS  Returns configuration changes for a VM
.DESCRIPTION The function will return the list of configuration changes
    for a given Virtual Machine
.NOTES  Author:  William Lam
.NOTES  Site:    www.williamlam.com
.NOTES  Comment: Modified example from Lucd's blog post http://www.lucd.info/2009/12/18/events-part-3-auditing-vm-device-changes/
.PARAMETER Vm
  Virtual Machine object to query configuration changes
.PARAMETER Hour
  The number of hours to to search for configuration changes, default 8hrs
.EXAMPLE
  PS> Get-VMConfigChanges -vm $VM
.EXAMPLE
  PS> Get-VMConfigChanges -vm $VM -hours 8
#>

Function Get-VMConfigChanges {
    param($vm, $hours=8)

    # Modified code from http://powershell.com/cs/blogs/tips/archive/2012/11/28/removing-empty-object-properties.aspx
    Function prettyPrintEventObject($vmChangeSpec,$task) {
    	$hashtable = $vmChangeSpec |
	    Get-Member -MemberType *Property |
    	Select-Object -ExpandProperty Name |
	    Sort-Object |
    	ForEach-Object -Begin {
  	    	[System.Collections.Specialized.OrderedDictionary]$rv=@{}
  	    	} -process {
  		    if ($vmChangeSpec.$_ -ne $null) {
    		    $rv.$_ = $vmChangeSpec.$_
      		}
	    } -end {$rv}

    	# Add in additional info to the return object (Thanks to Luc's Code)
    	$hashtable.Add('VMName',$task.EntityName)
	    $hashtable.Add('Start', $task.StartTime)
    	$hashtable.Add('End', $task.CompleteTime)
	    $hashtable.Add('State', $task.State)
    	$hashtable.Add('User', $task.Reason.UserName)
      $hashtable.Add('ChainID', $task.EventChainId)

    	# Device Change
	    $vmChangeSpec.DeviceChange | % {
		    if($_.Device -ne $null) {
          $hashtable.Add('Device', $_.Device.GetType().Name)
			    $hashtable.Add('Operation', $_.Operation)
        }
	    }
	    $newVMChangeSpec = New-Object PSObject
	    $newVMChangeSpec | Add-Member ($hashtable) -ErrorAction SilentlyContinue
	    return $newVMChangeSpec
    }

    # Modified code from Luc Dekens http://www.lucd.info/2009/12/18/events-part-3-auditing-vm-device-changes/
    $tasknumber = 999 # Windowsize for task collector
    $eventnumber = 100 # Windowsize for event collector

    $report = @()
    $taskMgr = Get-View TaskManager
    $eventMgr = Get-View eventManager

    $tFilter = New-Object VMware.Vim.TaskFilterSpec
    $tFilter.Time = New-Object VMware.Vim.TaskFilterSpecByTime
    $tFilter.Time.beginTime = (Get-Date).AddHours(-$hours)
    $tFilter.Time.timeType = "startedTime"
    $tFilter.Entity = New-Object VMware.Vim.TaskFilterSpecByEntity
    $tFilter.Entity.Entity = $vm.ExtensionData.MoRef
    $tFilter.Entity.Recursion = New-Object VMware.Vim.TaskFilterSpecRecursionOption
    $tFilter.Entity.Recursion = "self"

    $tCollector = Get-View ($taskMgr.CreateCollectorForTasks($tFilter))

    $dummy = $tCollector.RewindCollector
    $tasks = $tCollector.ReadNextTasks($tasknumber)

    while($tasks){
      $tasks | where {$_.Name -eq "ReconfigVM_Task"} | % {
        $task = $_
        $eFilter = New-Object VMware.Vim.EventFilterSpec
        $eFilter.eventChainId = $task.EventChainId

        $eCollector = Get-View ($eventMgr.CreateCollectorForEvents($eFilter))
        $events = $eCollector.ReadNextEvents($eventnumber)
        while($events){
          $events | % {
            $event = $_
            switch($event.GetType().Name){
              "VmReconfiguredEvent" {
                $event.ConfigSpec | % {
				    $report += prettyPrintEventObject $_ $task
                }
              }
              Default {}
            }
          }
          $events = $eCollector.ReadNextEvents($eventnumber)
        }
        $ecollection = $eCollector.ReadNextEvents($eventnumber)
	    # By default 32 event collectors are allowed. Destroy this event collector.
        $eCollector.DestroyCollector()
      }
      $tasks = $tCollector.ReadNextTasks($tasknumber)
    }

    # By default 32 task collectors are allowed. Destroy this task collector.
    $tCollector.DestroyCollector()

    $report
}

$vcserver = "192.168.1.150"
$vcusername = "administrator@vghetto.local"
$vcpassword = "VMware1!"

Connect-VIServer -Server $vcserver -User $vcusername -Password $vcpassword

$vm = Get-VM "Test-VM"

Get-VMConfigChanges -vm $vm -hours 1

Disconnect-VIServer -Server $vcserver -Confirm:$false
