#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://communities.vmware.com/docs/DOC-10637

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;

# validate options, and connect to the server
Opts::parse();
Opts::validate();
Util::connect();

my $rps = Vim::find_entity_views(view_type => 'ResourcePool');

print "Resource Pools:\n\n";

foreach my $rp ( sort {$a->name cmp $b->name} @$rps) {
	my $rp_name = $rp->name;
	print $rp_name . " - \n";
	my $vms = Vim::get_views(mo_ref_array => $rp->vm, properties => ['summary.config.name']);	
	foreach(@$vms) {
		print "\t" . $_->{'summary.config.name'} . "\n";
	}
	print "\n";
}

Util::disconnect();
