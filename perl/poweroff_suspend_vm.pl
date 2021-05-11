#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://communities.vmware.com/docs/DOC-10269

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
