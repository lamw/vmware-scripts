#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://www.virtuallyghetto.com/2011/09/how-to-use-custom-vm-icons-in-vsphere-5.html

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
   vmname => {
      type => "=s",
      help => "Name of VirtalMachine",
      required => 1,
   },
   key => {
      type => "=s",
      help => "Extension key (e.g. com.vmware.vGhetto)",
      required => 1,
   },
   type => {
      type => "=s",
      help => "Type",
      required => 1,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

unless(Vim::get_service_content()->about->apiVersion eq "5.0" && Vim::get_service_content()->about->productLineId eq "vpx") {
	print "ManagedBy property is only supported with vSphere vCenter 5.0!\n";
	Util::disconnect();
	exit;
}

my $vmname = Opts::get_option('vmname');
my $key = Opts::get_option('key');
my $type = Opts::get_option('type');

my $vm_view = Vim::find_entity_view(view_type => 'VirtualMachine',filter => {"config.name" => $vmname});

unless($vm_view) {
	print "Unable to locate $vmname!\n";
	Util::disconnect();
	exit;
}

eval {
	my $managedBy = ManagedByInfo->new(extensionKey => $key, type => $type);
	my $spec = VirtualMachineConfigSpec->new(managedBy => $managedBy);
	$vm_view->ReconfigVM_Task(spec => $spec);
};
if($@) {
	print $@ . "\n";
}

Util::disconnect();
