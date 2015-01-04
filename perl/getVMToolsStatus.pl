#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://communities.vmware.com/docs/DOC-10563

use strict;
use warnings;
use VMware::VIFPLib;
use VMware::VIRuntime;

Opts::parse();
Opts::validate();
Util::connect();

my $vm_views = Vim::find_entity_views(
                view_type => "VirtualMachine",
);

unless (defined $vm_views){
        die "No VMs found!\n";
}

my ($vmname,$hardware_version,$tools_version,$tools_status) = ('VM Name','vHardware','Tools Version','Tools Status');

format output =
@<<<<<<<<<<<<<<<<<<<<<<<<<@<<<<<<<<<<<<@<<<<<<<<<<<<<<<<<@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$vmname,        $hardware_version,  $tools_version, $tools_status
---------------------------------------------------------------------------------------
.

$~ = 'output';
write;

foreach( sort {$a->config->name cmp $b->config->name} @$vm_views) {
	$vmname = $_->config->name;
	if(defined($_->guest->toolsStatus)) {	
		$tools_status = $_->guest->toolsStatus->val;
		$tools_version = ($_->guest->toolsVersion ? $_->guest->toolsVersion : "N/A");
		$hardware_version = $_->config->version;
	} else {
		$tools_status = "Not defined";
	}
	write;
}

Util::disconnect();
