#!/usr/bin/perl -w
# Copyright (c) 2009-2014 William Lam All rights reserved.

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

# William Lam
# www.virtuallyghetto.com

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
