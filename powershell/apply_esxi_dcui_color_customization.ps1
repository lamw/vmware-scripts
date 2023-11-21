$vmhost = Get-VMHost
$vendor = "Broadcom"

## DO NOT EDIT BEYOND HERE ##

$build = $vmhost.build
$version = $vmhost.Version
$model = $vmhost.model
$numcpu = $vmhost.NumCpu
$processtype = $vmhost.ProcessorType
$nummem = [math]::ceiling($vmhost.MemoryTotalGB)
$name = $vmhost.name
$dhcp = ($vmhost.ExtensionData.config.VirtualNicManagerInfo.NetConfig | where {$_.NicType -eq "management"})[0].CandidateVnic.spec.ip.dhcp
if ($dhcp) {
    $ipv4string = "https://${name} (DHCP)"
} else {
    $ipv4string = "https://${name} (STATIC)"
}
$ipv6 = ($vmhost.ExtensionData.config.VirtualNicManagerInfo.NetConfig | where {$_.NicType -eq "management"})[0].CandidateVnic.spec.ip.IpV6Config.IpV6Address.IpAddress
$f2message = "<F2> Customize System/View Logs"
$f12message = "<F12> Shutdown/Restart"

$esxiMessage = @"
{bgcolor:white}{align:left}{color:black} {/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:white}{align:left}{color:black} {/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:white}{align:left}{color:black} {/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:white}{align:left}{color:black}                 $vendor ESXi $version (VMKernel Release Build $build) {/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:white}{align:left}{color:black} {/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:white}{align:left}{color:black}                 $vendor, Inc. $model {/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:white}{align:left}{color:black} {/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:white}{align:left}{color:black}                 $numcpu x $processtype {/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:white}{align:left}{color:black}                 $nummem GiB Memory {/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:white}{align:left}{color:black} {/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:white}{align:left}{color:black} {/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:white}{align:left}{color:black} {/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:white}{align:left}{color:black} {/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:white}{align:left}{color:black} {/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:white}{align:left}{color:black} {/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:white}{align:left}{color:black} {/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:white}{align:left}{color:black} {/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:white}{align:left}{color:black} {/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:white}{align:left}{color:black} {/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:red}{align:left}{color:white} {/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:red}{align:left}{color:white}                 To manage this host, go to:{/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:red}{align:left}{color:white}                 $ipv4string {/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:red}{align:left}{color:white}                 https://$ipv6 (STATIC){/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:red}{align:left}{color:white} {/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:red}{align:left}{color:white} {/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:red}{align:left}{color:white} {/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:red}{align:left}{color:white} {/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:red}{align:left}{color:white} {/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:red}{align:left}{color:white} {/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:red}{align:left}{color:white} {/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:red}{align:left}{color:white} {/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:red}{align:left}{color:white} {/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:red}{align:left}{color:white} {/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:red}{align:left}{color:white} {/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:red}{align:left}{color:white} {/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:red}{align:left}{color:white} {/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:red}{align:left}{color:white} {/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:red}{align:left}{color:white} {/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:red}{align:left}{color:white} {/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:red}{align:left}{color:white} {/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:red}{align:left}{color:white} {/align}{align:right}{/color}{/align}{/bgcolor}
{bgcolor:red}{align:left}{color:white} $f2message {/align}                                                                   $f12message {align:right}{/color}{/align}{/bgcolor}
{bgcolor:red}{align:left}{color:white} {/align}{align:right}{/color}{/align}{/bgcolor}
"@

$vmhost | Get-AdvancedSetting -Name Annotations.WelcomeMessage | Set-AdvancedSetting -Value $esxiMessage -Confirm:$false
