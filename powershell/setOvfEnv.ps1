# Author: William Lam
# Website: www.virtuallyghetto
# Product: VMware vCenter Server Apppliance
# Description: PowerCLI script to deploy VCSA directly to ESXi host
# Reference: http://www.williamlam.com/2014/06/an-alternate-way-to-inject-ovf-properties-when-deploying-virtual-appliances-directly-onto-esxi.html

$esxname = "mini.primp-industries.com"
$esx = Connect-VIServer -Server $esxname

# Name of VM
$vmname = "VCSA"

# Name of the OVF Env VM Adv Setting
$ovfenv_key = “guestinfo.ovfEnv”

# VCSA Example
$ovfvalue = "<?xml version=`"1.0`" encoding=`"UTF-8`"?> 
<Environment 
     xmlns=`"http://schemas.dmtf.org/ovf/environment/1`" 
     xmlns:xsi=`"http://www.w3.org/2001/XMLSchema-instance`" 
     xmlns:oe=`"http://schemas.dmtf.org/ovf/environment/1`" 
     xmlns:ve=`"http://www.vmware.com/schema/ovfenv`" 
     oe:id=`"`">
   <PlatformSection> 
      <Kind>VMware ESXi</Kind> 
      <Version>5.5.0</Version> 
      <Vendor>VMware, Inc.</Vendor> 
      <Locale>en</Locale> 
   </PlatformSection> 
   <PropertySection> 
         <Property oe:key=`"vami.DNS.VMware_vCenter_Server_Appliance`" oe:value=`"192.168.1.1`"/> 
         <Property oe:key=`"vami.gateway.VMware_vCenter_Server_Appliance`" oe:value=`"192.168.1.1`"/> 
         <Property oe:key=`"vami.hostname`" oe:value=`"vcsa.primp-industries.com`"/> 
         <Property oe:key=`"vami.ip0.VMware_vCenter_Server_Appliance`" oe:value=`"192.168.1.250`"/> 
         <Property oe:key=`"vami.netmask0.VMware_vCenter_Server_Appliance`" oe:value=`"255.255.255.0`"/>  
         <Property oe:key=`"vm.vmname`" oe:value=`"VMware_vCenter_Server_Appliance`"/>
   </PropertySection>
</Environment>"

# Adds "guestinfo.ovfEnv" VM Adv setting to VM
Get-VM $vmname | New-AdvancedSetting -Name $ovfenv_key -Value $ovfvalue -Confirm:$false -Force:$true

Disconnect-VIServer -Server $esx -Confirm:$false
