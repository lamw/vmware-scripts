#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://communities.vmware.com/docs/DOC-10190

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

Opts::parse();
Opts::validate();
Util::connect();

my ($hosts, $host);

$hosts = Vim::find_entity_views(view_type => 'HostSystem');

unless (defined $hosts){
	die "No hosts found.\n";	
}

foreach $host(@{$hosts}) {
	print "Searching Host: ", $host->name,"\n";
	my $vm_views = Vim::get_views(mo_ref_array => $host->vm, properties => ['summary.config.name','summary.runtime.connectionState']);
	foreach(sort {$a->{'summary.config.name'} cmp $b->{'summary.config.name'}} @$vm_views) {
		if($_->{'summary.runtime.connectionState'}->val eq 'orphaned') {
			print "\t",$_->{'summary.config.name'}, " ", $_->{'summary.runtime.connectionState'}->val," & Removed from inventory!\n";
			$_->UnregisterVM();
		}
	}
}
Util::disconnect();
