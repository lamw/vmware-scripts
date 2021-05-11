#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://www.williamlam.com/2014/07/how-to-generate-specific-support-log-bundles-for-vcenter-esxi-using-vsphere-api.html

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;

Opts::parse();
Opts::validate();
Util::connect();

# Diagnostic Manager
my $diagMgr = Vim::get_view(mo_ref => Vim::get_service_content()->diagnosticManager);

# Retrieve all ESXi hosts managed by VC
my $hosts = Vim::find_entity_views(view_type => 'HostSystem', properties => ['name']);

my @hosts_to_collect_logs;
foreach my $host (@$hosts) {
	# creat an array of ESXi hosts to collect logs
	push @hosts_to_collect_logs,$host;
}

eval {
	print "Generating vCenter & ESXi Log Bundle download URLs ...\n";
	my $task = $diagMgr->GenerateLogBundles_Task(host => \@hosts_to_collect_logs, includeDefault => 'true');
	my $results = &getStatus($task,"\tSuccessfully completed!");

	foreach my $result (@$results) {
		print $result->url . "\n";
	}
};
if($@) {
	print "Error: " . $@. "\n";
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
