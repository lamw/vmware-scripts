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
# http://communities.vmware.com/docs/DOC-10279
# http://engineering.ucsb.edu/~duonglt/vmware/

# import runtime libraries
use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;

# define custom options for vm and target host
my %opts = (
   'vmname' => {
      type => "=s",
      help => "The name of the virtual machine",
      required => 1,
   },
   'operation' => {
      type => "=s",
      help => "FT Operation to perform [create|enable|disable|stop]",
      required => 1,
   },
);

# read and validate command-line parameters
Opts::add_options(%opts);
Opts::parse();
Opts::validate();

# connect to the server and login
Util::connect();

my ($primaryVM,$task_ref);

if( Opts::get_option('operation') eq 'create' ) {
        $primaryVM = Vim::find_entity_view(view_type => 'VirtualMachine',
                                      filter => {"config.name" => Opts::get_option('vmname')});

        eval {
                $task_ref = $primaryVM->CreateSecondaryVM_Task();
                print "Creating FT secondary VM for \"" . $primaryVM->name . "\" ...\n";
                my $msg = "\tSuccessfully created FT protection for \"" . $primaryVM->name . "\"!";
                &getStatus($task_ref,$msg);
        };
        if ($@) {
                # unexpected error
                print "Error: " . $@ . "\n\n";
        }
} elsif( Opts::get_option('operation') eq 'enable' ) {
        $primaryVM = Vim::find_entity_view(view_type => 'VirtualMachine',
                                      filter => {"config.name" => Opts::get_option('vmname'), "config.ftInfo.role" => '1'});

        my $uuids = $primaryVM->config->ftInfo->instanceUuids;
        my $secondaryUuid = @$uuids[1];
        my $secondaryVM = Vim::find_entity_view(view_type => 'VirtualMachine',
                                      filter => {"config.instanceUuid" => $secondaryUuid});
        my $secondaryHost = Vim::get_view(mo_ref => $secondaryVM->runtime->host, properties => ['name']);

        eval {
                $task_ref = $primaryVM->EnableSecondaryVM_Task(vm => $secondaryVM);
                print "Enabling FT secondary VM for \"" . $primaryVM->name . "\" on host \"" . $secondaryHost->{'name'} . "\" ...\n";
                my $msg = "\tSuccessfully enabled FT protection for \"" . $primaryVM->name . "\"!";
                &getStatus($task_ref,$msg);
        };
        if ($@) {
                # unexpected error
                print "Error: " . $@ . "\n\n";
        }

} elsif( Opts::get_option('operation') eq 'disable' ) {
        $primaryVM = Vim::find_entity_view(view_type => 'VirtualMachine',
                                      filter => {"config.name" => Opts::get_option('vmname'), "config.ftInfo.role" => '1'});

        my $uuids = $primaryVM->config->ftInfo->instanceUuids;
        my $secondaryUuid = @$uuids[1];
        my $secondaryVM = Vim::find_entity_view(view_type => 'VirtualMachine',
                                      filter => {"config.instanceUuid" => $secondaryUuid});
        my $secondaryHost = Vim::get_view(mo_ref => $secondaryVM->runtime->host, properties => ['name']);

        eval {
                $task_ref = $primaryVM->DisableSecondaryVM_Task(vm => $secondaryVM);
                print "Disabling FT secondary VM for \"" . $primaryVM->name . "\" on host \"" . $secondaryHost->{'name'} . "\" ...\n";
                my $msg = "\tSuccessfully disabled FT protection for \"" . $primaryVM->name . "\"!";
                &getStatus($task_ref,$msg);
        };
        if ($@) {
                # unexpected error
                print "Error: " . $@ . "\n\n";
        }
} elsif( Opts::get_option('operation') eq 'stop' ) {
        $primaryVM = Vim::find_entity_view(view_type => 'VirtualMachine',
                                      filter => {"config.name" => Opts::get_option('vmname'), "config.ftInfo.role" => '1'});

        eval {
                $task_ref = $primaryVM->TurnOffFaultToleranceForVM_Task();
                print "Turning off FT for secondary VM for " . $primaryVM->name . " ...\n";
                my $msg = "\tSuccessfully stopped FT protection for \"" . $primaryVM->name . "\"!";
                &getStatus($task_ref,$msg);
        };
        if ($@) {
                # unexpected error
                print "Error: " . $@ . "\n\n";
        }
} else {
        print "Invalid operation!\n";
        print "Operations supported [create|enable|disable|stop]\n\n";
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

# close server connection
Util::disconnect();
