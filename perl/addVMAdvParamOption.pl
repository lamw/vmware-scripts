#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://www.virtuallyghetto.com/2011/01/how-to-extract-host-information-from.html

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
   key => {
      type => "=s",
      help => "Name of advanced parameter",
      required => 1,
   },
   vmname => {
      type => "=s",
      help => "Name of VM to add/update advanced paraemter",
      required => 1,
   },
   value => {
      type => "=s",
      help => "Value of of advanced parameter",
      required => 1,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $key = Opts::get_option('key');
my $value = Opts::get_option('value');
my $vmname = Opts::get_option('vmname');

my $vm = Vim::find_entity_view(view_type => 'VirtualMachine',
			filter => {"config.name" => $vmname});

unless ($vm) {
	print "Unable to find VM: \"$vmname\"!\n";
        exit 1
}

my $extra_conf = OptionValue->new(key => $key, value => $value);

eval {
	my $spec = VirtualMachineConfigSpec->new(extraConfig => [$extra_conf]);
	print "Reconfiguring \"$vmname\" with advanced parameter configuration: \"$key=>$value\" ...\n";
	my $task = $vm->ReconfigVM_Task(spec => $spec);	
	my $msg = "Sucessfully updated advanced parameter configuration for \"$vmname\"!";
	&getStatus($task,$msg);
};

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
