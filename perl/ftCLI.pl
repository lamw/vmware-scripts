#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://communities.vmware.com/docs/DOC-10279

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
