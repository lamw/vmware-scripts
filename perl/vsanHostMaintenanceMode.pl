#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://www.virtuallyghetto.com/2014/04/exploring-vsan-apis-part-8-maintenance-mode.html

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;

# define custom options for vm and target host
my %opts = (
	 'vihost' => {
			type => "=s",
			help => "Name of ESXi host to perform operation on",
			required => 1,
		},
		'operation' => {
			type => "=s",
			help => "Operation to perform [enter|exit]",
			required => 1,
		},
		'mode' => {
			type => "=s",
			help => "Enter maintenance mode option [ensure|evac|no]",
			required => 0,
		},
);

$SIG{__DIE__} = sub{Util::disconnect()};

# read and validate command-line parameters 
Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $vihost = Opts::get_option("vihost");
my $operation = Opts::get_option("operation");
my $mode = Opts::get_option("mode");

# VSAN Maint Mode Actions (VsanHostDecommissionModeObjectAction)
my %modeSelection = ('ensure','ensureObjectAccessibility','evac','evacuateAllData','no','noAction');

my $host_view = Vim::find_entity_view(view_type => 'HostSystem', filter => { 'name' => $vihost}, properties => ['name']);
unless($host_view) {
	Util::disconnect();
	print "Error: Unable to find ESXi host " . $vihost . "\n";
	exit 1;
}

if($operation eq "enter") {
	unless($mode) {
		Util::disconnect();
		print "\"Enter\" operation requires --mode option to be specified\n";
		exit 1;
	}

	eval {
		my $vsanMode = VsanHostDecommissionMode->new(objectAction => $modeSelection{$mode});
		my $spec = HostMaintenanceSpec->new(vsanMode => $vsanMode);
		print "Putting " . $vihost . " into maintenance mode ...\n";
		my $task = $host_view->EnterMaintenanceMode_Task(timeout => 0, evacuatePoweredOffVms => 'true', maintenanceSpec => $spec);
		my $msg = "Successfully entered maintenance mode";
		&getStatus($task,$msg);
	};
	if($@) {
		print "Error: " . $@ . "\n";
	}
} elsif($operation eq "exit") {
	eval {
		print "Taking " . $vihost . " out of maintenance mode ...\n";
		$host_view->ExitMaintenanceMode_Task(timeout => 0);
	};
	if($@) {
		print "Error: " . $@ . "\n";
	}	
} else {
	print "Invalid Selection\n";
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

