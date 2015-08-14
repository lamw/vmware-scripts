<#
.SYNOPSIS  Returns configuration changes for a VM using vCenter Server Alarm
.DESCRIPTION The function will return the list of configuration changes
    for a given Virtual Machine trigged by vCenter Server Alarm based on
    VmReconfigureEvent
.NOTES  Author:  William Lam
.NOTES  Site:    www.virtuallyghetto.com
.NOTES  Comment: Modified example from Lucd's blog post http://www.lucd.info/2009/12/18/events-part-3-auditing-vm-device-changes/
.PARAMETER Moref
  Virtual Machine MoRef ID that generated vCenter Server Alarm
.PARAMETER EventId
  The ID correlating to the ReconfigVM operation
.EXAMPLE
  PS> Get-VMConfigChanges -moref vm-125 -eventId 8389
#>

Function Get-VMConfigChangesFromAlarm {
    param($moref, $eventId)

    # Construct VM object from MoRef ID
    $vm = New-Object VMware.Vim.ManagedObjectReference
    $vm.Type = "VirtualMachine"
    $vm.Value = $moref

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
    # Need to take eventId substract 1 to get real event
    $tFilter.eventChainId = ([int]$eventId - 1)
    $tFilter.Entity = New-Object VMware.Vim.TaskFilterSpecByEntity
    $tFilter.Entity.Entity = $vm
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

    $report | Out-File -filepath C:\Users\primp\Desktop\alarm.txt -Append
}

$vcserver = "172.30.0.112"
$vcusername = "administrator@vghetto.local"
$vcpassword = "VMware1!"

Connect-VIServer -Server $vcserver -User $vcusername -Password $vcpassword

# Parse vCenter Server Alarm environmental variables
$eventid_from_alarm = $env:VMWARE_ALARM_TRIGGERINGSUMMARY
$moref_from_alarm = $env:VMWARE_ALARM_TARGET_ID

# regex for string within paren http://powershell.com/cs/forums/p/7360/11988.aspx
$regex = [regex]"\((.*)\)"
$string = [regex]::match($eventid_from_alarm, $regex).Groups[1]
$eventid = $string.value

Get-VMConfigChangesFromAlarm -moref $moref_from_alarm -eventId $eventid

Disconnect-VIServer -Server $vcserver -Confirm:$false
