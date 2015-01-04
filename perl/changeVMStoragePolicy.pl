#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://www.virtuallyghetto.com/2014/03/exploring-vsan-apis-part-6-modifying-virtual-machine-vm-storage-policy.html

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
   vmname => {
      type => "=s",
      help => "Name of VM",
      required => 1,
   },
   profileid  => {
      type => "=s",
      help => "Managed Object Reference (MoRef) ID of VM Storage Policy from SPBM API",
      required => 1,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $vmname = Opts::get_option('vmname');
my $profileid = Opts::get_option('profileid');

my $vm = Vim::find_entity_view(view_type => 'VirtualMachine', filter => {"config.name" => $vmname});

unless ($vm) {
	print "Unable to find VM: \"$vmname\"!\n";
        exit 1
}

eval {
	print "Reconfiguring " . $vmname . " to use VM Storage Policy (" . $profileid . ") ...\n";

	# define VM Storage Policy spec for VM Home
	print "Setting VM Home ... \n";
	my $vmprofile = VirtualMachineDefinedProfileSpec->new(profileId => $profileid);

	# define VM Storage Policy for VMDKs
	my $devices = $vm->config->hardware->device;
	my @devicespec = &buildVMDKSpec($devices,$profileid);

	my $vmspec = VirtualMachineConfigSpec->new(vmProfile => [$vmprofile], deviceChange => \@devicespec);
	my $task = $vm->ReconfigVM_Task(spec => $vmspec);
	my $msg = "\tSucessfully reconfigured " . $vmname . "\n";
	&getStatus($task,$msg);
};
if($@) {
	print "Error: " . $@ . "\n";
}

Util::disconnect();

sub buildVMDKSpec {
	my ($devices,$profileid) = @_;

	my @virtualdisks = ();
	foreach my $device(@$devices) {
		if($device->isa('VirtualDisk')) {
			push @virtualdisks,$device;
		}
	}

	my @result = ();
	foreach my $virtualdisk(@virtualdisks) {
		print "Setting VMDK " . $virtualdisk->deviceInfo->label . " ...\n";
		my $diskprofile = VirtualMachineDefinedProfileSpec->new(profileId => $profileid);
		my $operation = VirtualDeviceConfigSpecOperation->new('edit');
		my $tmp = VirtualDeviceConfigSpec->new(device => $virtualdisk, operation => $operation, profile => [$diskprofile]);
		push @result,$tmp;
	}

	return @result;
}

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
