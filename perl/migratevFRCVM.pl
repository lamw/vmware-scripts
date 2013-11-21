#!/usr/bin/perl -w
# Copyright (c) 2009-2013 William Lam All rights reserved.

# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. The name of the author or contributors may not be used to endorse or
#    promote products derived from this software without specific prior
#    written permission.
# 4. Consent from original author prior to redistribution

# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
# William Lam
# www.virtuallyghetto.com

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
