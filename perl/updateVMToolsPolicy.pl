#!/usr/bin/perl -w
# Copyright (c) 2009-2012 William Lam All rights reserved.

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
# 4. Written Consent from original author prior to redistribution

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
# http://www.virtuallyghetto.com/

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
   vmfile => {
      type => "=s",
      help => "List of VMs",
      required => 0,
   },
   policy => {
      type => "=s",
      help => "VMware Tools Policy [manual|upgradeAtPowerCycle]",
      required => 0,
   },
   operation => {
      type => "=s",
      help => "[list|update]",
      required => 1,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $vmfile = Opts::get_option('vmfile');
my $policy = Opts::get_option('policy');
my $operation = Opts::get_option('operation');
my @vmList = ();

if($operation eq "list") {
	my $vms = Vim::find_entity_views(view_type => 'VirtualMachine',properties => ['name','config.tools']);
	
	foreach my $vm (sort {$a->{'name'} cmp $b->{'name'}} @$vms) {
		if(defined($vm->{'config.tools'})) {
			print "\"" . $vm->{'name'} . "\"\t" . "\"" . $vm->{'config.tools'}->toolsUpgradePolicy . "\"\n";
		} else {
			print "\"" . $vm->{'name'} . "\"\t" . "\"NO-TOOLS-CONFIG\"\n";
		}
	}
} elsif($operation eq "update") {
	unless($vmfile && $policy) {
		print "\n\"update\" operation requires vmfile and policy to be specified!\n";
		Util::disconnect();
		exit 1;
	}
	&processFile($vmfile);

	foreach my $vm (@vmList) {
		my $vm_view =  Vim::find_entity_view(view_type => 'VirtualMachine',properties => ['name'], filter => {"name" => $vm});
		if($vm_view) {
			eval {
				print "Updating VMware Tools Policy for " . $vm . " to " . $policy . " ...\n";
				my $toolsConfig = ToolsConfigInfo->new(toolsUpgradePolicy => $policy);
				my $spec = VirtualMachineConfigSpec->new(tools => $toolsConfig);
	        		my $task = $vm_view->ReconfigVM_Task(spec => $spec);
				my $msg = "\tSuccessfully completed reconfiguration!";
				&getStatus($task,$msg);
			};
			if($@) { print "Error " . $@ . "\n"; }
		} else {
			print "Unable to locate VM: " . $vm . "\n";
		}
	}
} else {
	print "Invalid operation!\n";
}

Util::disconnect();

# Subroutine to process the input file
sub processFile {
        my ($conf) = @_;

        open(CONFIG, "$conf") || die "Error: Couldn't open the $conf!";
        while (<CONFIG>) {
                chomp;
                s/#.*//; # Remove comments
                s/^\s+//; # Remove opening whitespace
                s/\s+$//;  # Remove closing whitespace
                next unless length;
                chomp($_);
		push(@vmList,$_);
        }
        close(CONFIG);
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
                sleep 2;
                $task_view->ViewBase::update_view_data();
        }
}
