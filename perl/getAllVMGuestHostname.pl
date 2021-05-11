#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://communities.vmware.com/docs/DOC-10500

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;

# validate options, and connect to the server
Opts::parse();
Opts::validate();
Util::connect();

my $vm_view = Vim::find_entity_views(view_type => 'VirtualMachine');

print "VM Display Name\t\tVM Guest Hostname\t\tVMware Tools Status\n";
print "------------------------------------------------------------------------\n";
foreach( sort {$a->summary->config->name cmp $b->summary->config->name}  @$vm_view) {
	my $vm_display_name = $_->summary->config->name;
	my $vm_hostname;
	my $tools_status;
	if(defined($_->guest)) {
		if(defined($_->guest->hostName)) {
			$vm_hostname = $_->guest->hostName;
		} else {
			$vm_hostname = "Not Available";
		}
	} else {
		$vm_hostname = "Not Available"
	}
	$tools_status = $_->guest->toolsStatus->val;
	print $vm_display_name . "\t\t" . $vm_hostname . "\t\t" . $tools_status . "\n";
}

Util::disconnect();
