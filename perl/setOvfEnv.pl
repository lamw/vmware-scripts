#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://www.virtuallyghetto.com/2014/06/an-alternate-way-to-inject-ovf-properties-when-deploying-virtual-appliances-directly-onto-esxi.html

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;

my %opts = (
   vmname => {
      type => "=s",
      help => "Name of VM to query for advanced option",
      required => 1,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $vmname = Opts::get_option('vmname');

my $key = "guestinfo.ovfEnv";
# Log Insight 2.0 Example
my $ovfValue = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<Environment
     xmlns=\"http://schemas.dmtf.org/ovf/environment/1\"
     xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"
     xmlns:oe=\"http://schemas.dmtf.org/ovf/environment/1\"
     xmlns:ve=\"http://www.vmware.com/schema/ovfenv\"
     oe:id=\"\"
   <PlatformSection>
      <Kind>VMware ESXi</Kind>
      <Version>5.5.0</Version>
      <Vendor>VMware, Inc.</Vendor>
      <Locale>en</Locale>
   </PlatformSection>
   <PropertySection>
         <Property oe:key=\"vami.DNS.VMware_vCenter_Log_Insight\" oe:value=\"192.168.1.1\"/>
         <Property oe:key=\"vami.gateway.VMware_vCenter_Log_Insight\" oe:value=\"192.168.1.1\"/>
         <Property oe:key=\"vami.hostname.VMware_vCenter_Log_Insight\" oe:value=\"vclog.primp-industries.com\"/>
         <Property oe:key=\"vami.ip0.VMware_vCenter_Log_Insight\" oe:value=\"192.168.1.251\"/>
         <Property oe:key=\"vami.netmask0.VMware_vCenter_Log_Insight\" oe:value=\"255.255.255.0\"/>
         <Property oe:key=\"vm.rootpw\" oe:value=\"vmware123\"/>
         <Property oe:key=\"vm.vmname\" oe:value=\"VMware_vCenter_Log_Insight\"/>
   </PropertySection>
</Environment>";

my $vm = Vim::find_entity_view(view_type => 'VirtualMachine', filter => {'name' => $vmname}, properties => ['name','runtime.powerState','config.extraConfig']);

unless($vm) {
	print "Unable to locate " . $vmname . "\n";
	Util::disconnect();
	exit 1;
}

eval {
  print "Updating " . $vmname . " with advanced setting: " . $key . "=" . $ovfValue . " ...\n";
  my $option = OptionValue->new(key => $key, value => $ovfValue);
  my $vmSpec = VirtualMachineConfigSpec->new(extraConfig => [$option]);
  my $task = $vm->ReconfigVM_Task(spec => $vmSpec);
  &getStatus($task,"Successfully updated advanced setting for " . $vmname);
};
if($@) {
  print "Error: Unable to update option - \"" . $key ."=" . $ovfValue . "\" " . $@ . "\n";
}
 
Util::disconnect();

sub getStatus {
  my ($taskRef,$message) = @_;

  my $task_view = Vim::get_view(mo_ref => $taskRef);
  my $taskinfo = $task_view->info->state->val;
  my $continue = 1;
  while ($continue) {
    my $info = $task_view->info;
    if ($info->state->val eq 'success') {
      print $message,"\n";
      return $info->result;
      $continue = 0;
    } elsif ($info->state->val eq 'error') {
      my $soap_fault = SoapFault->new;
      $soap_fault->name($info->error->fault);
      $soap_fault->detail($info->error->fault);
      $soap_fault->fault_string($info->error->localizedMessage);
      die "$soap_fault\n";
    }
    sleep 5;
    $task_view->ViewBase::update_view_data();
  }
}
