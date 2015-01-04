#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://www.virtuallyghetto.com/2013/11/exploring-vsphere-flash-read-cache-vfrc_18.html

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
	vmname => {
		type => "=s",
                help => "Name of Virtual Machine to migrate",
		required => 1,
	},
	dst_vihost => {
                type => "=s",
                help => "Name of destination ESXi host to migrate VM to",
                required => 1,
        },
	priority => {
		type => "=s",
                help => "Migration priority [high|low]",
                required => 0,
		default => 'high',
	},
	migrate_cache => {
                type => "=s",
                help => "Migrate vFRC cache [true|false]",
                required => 0,
                default => 'true',
        },
);

Opts::add_options(%opts);

Opts::parse();
Opts::validate();
Util::connect();

my $vmname = Opts::get_option('vmname');
my $dst_vihost = Opts::get_option('dst_vihost');
my $priority = Opts::get_option('priority');
my $migrate_cache = Opts::get_option('migrate_cache');

# define priority enums
my %priorityConstants = ('high' => 'highPriority', 'low' => 'lowPriority');

# retrieve VM
my $vm_view = Vim::find_entity_view(view_type => 'VirtualMachine', filter => {'name' => $vmname}, properties => ['name','config.hardware.device']);
if(!defined($vm_view)) {
	&seeya("Unable to find VM: " . $vmname . "\n")
}

# Extract VirtualDisk Devices
my @disks;
my $devices = $vm_view->{'config.hardware.device'};
foreach my $device(@$devices) {
	if($device->isa('VirtualDisk')) {
		push @disks,$device;
	}
}

# retrieve host
my $host_view = Vim::find_entity_view(view_type => 'HostSystem', filter => {'name' => $dst_vihost}, properties => ['name']);
if(!defined($host_view)) {
        &seeya("Unable to find ESXi host: " . $dst_vihost . "\n");
}

# in case bad input
if($priority ne "low" || $priority ne "high") {
	$priority = "high";
}

# List of VirtualDisks to migrate vFRC cache
my @deviceChangeSpec;
foreach my $disk(@disks) {
	my $tmpSpec = VirtualDiskConfigSpec->new(device => $disk, migrateCache => $migrate_cache);
	push @deviceChangeSpec,$tmpSpec;
}

# RelocateSpec 
my $spec = VirtualMachineRelocateSpec->new(host => $host_view, deviceChange => \@deviceChangeSpec);
my $migrationPriority = VirtualMachineMovePriority->new($priorityConstants{$priority});

my ($task,$message);
eval {
	# call relocate API
	print "Migrating " . $vmname . " to ESXi Host: " . $dst_vihost . " with vFRC caching migrate=" . $migrate_cache . " ...\n";
	$task = $vm_view->RelocateVM_Task(spec => $spec, priority => $migrationPriority);
	$message = "Successfully migrated " . $vmname . "!\n";
	&getStatus($task,$message);
};
if($@) {
	print "Error: " . $@ . "\n";
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

sub seeya {
	my ($message) = @_;

	print $message;
	Util::disconnect();
	exit 1;
}
