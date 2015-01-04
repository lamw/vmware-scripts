#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://www.virtuallyghetto.com/2013/08/automate-enabling-vm-storage-profiles.html

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
	cluster => {
	type => "=s",
        help => "Name of the vCenter cluster",
	required => 1,
	},
	operation => {
        type => "=s",
        help => "enable|disable|query",
        required => 1,
        },
);

# validate options, and connect to the server
Opts::add_options(%opts);

# validate options, and connect to the server
Opts::parse();
Opts::validate();
Util::connect();

my $cluster = Opts::get_option('cluster');
my $operation = Opts::get_option('operation');
my %state = ('enable','true','disable','false');

my $cluster_view = Vim::find_entity_view(view_type => 'ClusterComputeResource', filter => { name => $cluster });
unless ($cluster_view){
	Util::disconnect();
	die "No cluster found with name $cluster\n";	
}

if($operation eq "query") {
	print "VM Storage Profiles is " . ($cluster_view->configurationEx->spbmEnabled ? "enabled" : "disabled") . " on " . $cluster . "\n";
} elsif($operation eq "enable" || $operation eq "disable") {
	eval {
		print $operation . " VM Storage Profiles on cluster: \"" . $cluster . "...\n";
		my $clusterConfigSpec = ComputeResourceConfigSpec->new(spbmEnabled => $state{$operation});
		my $taskRef = $cluster_view->ReconfigureComputeResource_Task(spec => $clusterConfigSpec, modify => 'true');
		my $msg = "\tSuccessfully " . $operation . " VM Storage Profiles on cluster: \"" . $cluster . "\"\n";
		&getStatus($taskRef,$msg);
	};
	if($@) {
		print "Error: " . $@ . "\n";
	}
} else {
	print "Invalid selection!\n";
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
