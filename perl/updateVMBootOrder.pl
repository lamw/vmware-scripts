#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://www.virtuallyghetto.com/2011/07/2-hidden-virtual-machine-gems-in.html

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;

my %opts = (
        'vmname' => {
        type => "=s",
        help => "The name of the virtual machine",
        required => 1,
        },
        'operation' => {
        type => "=s",
        help => "Operation [list|listnic|listdisk|update]",
        required => 1,
        },
        'bootorder' => {
        type => "=s",
        help => "Order of boot devices [ethernet,cdrom,disk,floppy]",
        required => 0,
        },
	'nickey' => {
        type => "=s",
        help => "device key for ethernet, use listnic to retrieve",
	required => 0,
        },
	'diskkey' => {
        type => "=s",
        help => "device key for disk, use listdisk to retrieve",
        required => 0,
        },
);
# validate options, and connect to the server
Opts::add_options(%opts);

# validate options, and connect to the server
Opts::parse();
Opts::validate();
Util::connect();

my $vmname = Opts::get_option ('vmname');
my $operation = Opts::get_option ('operation');
my $bootorder = Opts::get_option ('bootorder');
my $nickey = Opts::get_option ('nickey');
my $diskkey = Opts::get_option ('diskkey');

my $vm_view = Vim::find_entity_view(view_type => 'VirtualMachine', filter =>{ 'name'=> $vmname}, properties => ['config']);

if($vm_view) {
	if($operation eq "listnic" || $operation eq "listdisk") {
		my $devices = $vm_view->config->hardware->device;
		foreach(@$devices) {
			if($operation eq "listnic" && $_->isa('VirtualEthernetCard')) {
				print $_->deviceInfo->label . "\t" . $_->key . "\n";
			} elsif($operation eq "listdisk" && $_->isa('VirtualDisk')) {
				print $_->deviceInfo->label . "\t" . $_->key . "\n";
			}
		}
	} elsif($operation eq "list") {
		if($vm_view->{'config'}->{'bootOptions'}) {
			if($vm_view->{'config'}->bootOptions->bootOrder) {
				print Dumper($vm_view->{'config'}->bootOptions->bootOrder);
			} else {
				print "\nNo VMware boot order configured\n";
			}
		} else {
			print "\nNo boot options configured for this VM\n";
		}
	} elsif($operation eq "update") {
		unless($bootorder) {
			Util::disconnect();
			print "\nPlease specify the order of boot devices using --bootorder option\n";
			exit 1;
		}

		my @bootOptions = ();
		my @bootDevs = split(',',$bootorder);
		foreach(@bootDevs) {
			my $tmpBootDev = '';
			if($_ eq "ethernet" && defined($nickey)) {
				$tmpBootDev = VirtualMachineBootOptionsBootableEthernetDevice->new(deviceKey => $nickey);
			} elsif($_ eq "cdrom") {
				$tmpBootDev = VirtualMachineBootOptionsBootableCdromDevice->new();
			} elsif($_ eq "disk" && defined($diskkey)) {
				$tmpBootDev = VirtualMachineBootOptionsBootableDiskDevice->new(deviceKey => $diskkey);
			} elsif($_ eq "floppy") {
				$tmpBootDev = VirtualMachineBootOptionsBootableFloppyDevice->new();
			} else {
				print "Invalid Boot Device Selection!\n";
				Util::disconnect();
				exit 1;
			}
			push @bootOptions, $tmpBootDev;
		}

		my $bootOptions = VirtualMachineBootOptions->new(bootOrder => \@bootOptions);
		my $spec = VirtualMachineConfigSpec->new(bootOptions => $bootOptions);
		my $msg = "Successfully updated VM Boot Options";
		print "Reconfiguring VM Boot Options ...\n";
		my $task = $vm_view->ReconfigVM_Task(spec => $spec);
		&getStatus($task,$msg);
	} else {
		print "\nInvalid Operation\n";	
	}
} else {
        print "\nUnable to locate $vmname!\n";
        exit 0;
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

=head1 NAME

updateVMBootOrder.pl - Script to update Virtual Machines Boot Device Order (change is outside of BIOS)

=head1 Examples

=over 4

=item List current boot device order

=item

./updateVMBootOrder.pl --server [VCENTER_SERVER|ESXi] --username [USERNAME] --vmname [VMNAME] --operation list

=item List current Ethernet device key

=item

./updateVMBootOrder.pl --server [VCENTER_SERVER|ESXi] --username [USERNAME] --vmname [VMNAME] --operation listnic

=item List current Disk device key

=item

./updateVMBootOrder.pl --server [VCENTER_SERVER|ESXi] --username [USERNAME] --vmname [VMNAME] --operation listdisk

=item Update boot order devices (ethernet,cdrom,disk,floppy)

=item

./updateVMBootOrder.pl --server [VCENTER_SERVER|ESXi] --username [USERNAME] --vmname [VMNAME] --operation update --bootorder [ORDER_OF_DEVICES] [--nickey|--diskkey]

=back


=head1 SUPPORT

vSphere 5.0

=head1 AUTHORS

William Lam, http://www.virtuallyghetto.com/

=cut
