# William Lam
# www.virtuallyghetto.com

$vcname = "192.168.1.150"
$vcuser = "administrator@vghetto.local"
$vcpass = "VMware1!"

$ovffile = "Z:\Desktop\Nested_ESXi_Appliance.ovf"

$cluster = "MacMini-Cluster"
$vmnetwork = "VM Network"
$datastore = "mini-local-datastore-1"
$iprange = "192.168.1"
$netmask = "255.255.255.0"
$gateway = "192.168.1.1"
$dns = "192.168.1.1"
$dnsdomain = "primp-industries.com"
$ntp = "192.168.1.1"
$syslog = "192.168.1.150"
$password = "VMware1!"
$ssh = "True"

#### DO NOT EDIT BEYOND HERE ####

$vcenter = Connect-VIServer $vcname -User $vcuser -Password $vcpass -WarningAction SilentlyContinue

$datastore_ref = Get-Datastore -Name $datastore
$network_ref = Get-VirtualPortGroup -Name $vmnetwork
$cluster_ref = Get-Cluster -Name $cluster
$vmhost_ref = $cluster_ref | Get-VMHost | Select -First 1

$ovfconfig = Get-OvfConfiguration $ovffile
$ovfconfig.NetworkMapping.VM_Network.value = $network_ref

190..192 | Foreach {
    $ipaddress = "$iprange.$_"
    # Try to perform DNS lookup
    try {
        $vmname = ([System.Net.Dns]::GetHostEntry($ipaddress).HostName).split(".")[0]
    }
    Catch [system.exception]
    {
        $vmname = "vesxi-vsan-$ipaddress"
    }
    $ovfconfig.common.guestinfo.hostname.value = $vmname
    $ovfconfig.common.guestinfo.ipaddress.value = $ipaddress
    $ovfconfig.common.guestinfo.netmask.value = $netmask
    $ovfconfig.common.guestinfo.gateway.value = $gateway
    $ovfconfig.common.guestinfo.dns.value = $dns
    $ovfconfig.common.guestinfo.domain.value = $dnsdomain
    $ovfconfig.common.guestinfo.ntp.value = $ntp
    $ovfconfig.common.guestinfo.syslog.value = $syslog
    $ovfconfig.common.guestinfo.password.value = $password
    $ovfconfig.common.guestinfo.ssh.value = $ssh

    # Deploy the OVF/OVA with the config parameters
    Write-Host "Deploying $vmname ..."
    $vm = Import-VApp -Source $ovffile -OvfConfiguration $ovfconfig -Name $vmname -Location $cluster_ref -VMHost $vmhost_ref -Datastore $datastore_ref -DiskStorageFormat thin
    $vm | Start-Vm -RunAsync | Out-Null
}

Disconnect-VIServer $vcenter -Confirm:$false
