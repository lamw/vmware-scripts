#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://communities.vmware.com/docs/DOC-10490

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;

# validate options, and connect to the server
Opts::parse();
Opts::validate();
Util::connect();

my $vm_view = Vim::find_entity_views(view_type => 'VirtualMachine');

foreach(@$vm_view) {
	my $vm_name = $_->summary->config->name;
	my $devices =$_->config->hardware->device;
	my $mac_string;
	foreach(@$devices) {
		if($_->isa("VirtualEthernetCard")) {
			$mac_string .= "\t[" . $_->deviceInfo->label . "] : " . $_->macAddress . "\n";
		}
	}
	print $vm_name . "\n" . $mac_string . "\n";
}

Util::disconnect();
