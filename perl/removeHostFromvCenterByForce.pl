#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://communities.vmware.com/message/1341108

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
   host => {
      type => "=s",
      help => "Name of ESX(i) Server to remove from vCenter",
      required => 1,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $host = Opts::get_option('host');

my ($host_view);

$host_view = Vim::find_entity_view(view_type => 'HostSystem', filter => { name => $host });

unless (defined $host_view){
	die "Unable to find host!\n";	
}

print "\nFound Host: " . $host_view->name . " with state: "  . $host_view->runtime->connectionState->val  . "\n";
print "Would you like to remove this host from vCenter? y|n\n";
my $ans = <STDIN>;
chomp($ans);
if($ans eq 'n') {
	print "Leaving host alone, for now ...\n";
	exit 1
} elsif ($ans eq 'y') {
	print "Destroying host \"" . $host_view->name . "\"\n";
	my $task_ref = $host_view->Destroy_Task();	
	my $msg = "Successfully removed \"" . $host_view->name . "\"!";
	&getStatus($task_ref,$msg);
} else {
	print "Please enter y|n!\n";
	exit 1
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
