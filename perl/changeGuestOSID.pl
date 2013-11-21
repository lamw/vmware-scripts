#!/usr/bin/perl -w
# William Lam
# http://www.virtuallyghetto.com/

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

$SIG{__DIE__} = sub{Util::disconnect()};

my %opts = (
   vm => {
      type => "=s",
      help => "Name of VM",
      required => 1,
   },
   guestid => {
      type => "=s",
      help => "GuestOS ID",
      required => 1,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $vmname = Opts::get_option('vm');
my $guestid = Opts::get_option('guestid');

my $vm = Vim::find_entity_view(view_type => 'VirtualMachine', filter => {name => $vmname});
my $vmspec = VirtualMachineConfigSpec->new(guestId => $guestid);

eval {
        print "Reconfiguring guestId " . $guestid . " for " . $vm->name . "\n";
        my $task = $vm->ReconfigVM_Task(spec => $vmspec);
        my $msg = "\tSucessfully reconfigured " . $vm->name . "\n";
        &getStatus($task,$msg);

};
if($@) {
        print "ERROR " . $@ . "\n";
}


Util::disconnect();

#### HELPER #####

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
