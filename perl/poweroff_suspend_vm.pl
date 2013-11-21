#!/usr/bin/perl -w
# Copyright (c) 2009-2010 William Lam All rights reserved.

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
# http://communities.vmware.com/docs/DOC-10269
# http://engineering.ucsb.edu/~duonglt/vmware

use strict;
use warnings;

use VMware::VIRuntime;

my %opts = (
	vmfile => {
	type => "=s",
	help => "Path to file containing list of virtual machines, one per line, for ordered shutdown.",
	required => 1,
	},
	operation => {
	type => "=s",
        help => "Operation to perform [poweroff|suspend]",
        required => 1,
        },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();

Util::connect();

my ($vm_name, $vm_view, $vm_file, $operation,$task_ref);

$vm_file = Opts::get_option("vmfile");
$operation = Opts::get_option("operation");

open (VMFILE, $vm_file) or die "Failed to open file, '$vm_file'";
my @vm_list = <VMFILE>;
foreach $vm_name( @vm_list ) {
	chomp($vm_name);

	$vm_view = Vim::find_entity_view(
        	view_type => "VirtualMachine",
        	filter => { 'name' => $vm_name },
	);

	unless ( defined $vm_view ) {
	        die "Virtual Machine, '$vm_name', not found.\n";
	}

	if($operation eq 'suspend') {
		print "Trying to suspend " . $vm_name . "\n";
		eval {
        		$task_ref = $vm_view->SuspendVM_Task();
			my $msg = "\tSuccessfully suspended " . $vm_name . "\n";
			&getStatus($task_ref,$msg);
       		};
		if($@) { print "Error: " . $@ . "\n"; }
	} elsif($operation eq 'poweroff') {
		print "Trying to poweroff " . $vm_name . "\n";
		eval {
			$task_ref = $vm_view->PowerOffVM_Task();
                        my $msg = "\tSuccessfully poweredoff " . $vm_name . "\n";
			&getStatus($task_ref,$msg);
                };
                if($@) { print "Error: " . $@ . "\n"; }
	} else {
		print "Invalid operation!\n";
	}
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
                        print $message;
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
