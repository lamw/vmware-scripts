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

