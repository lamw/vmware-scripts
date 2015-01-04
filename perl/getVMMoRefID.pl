#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://communities.vmware.com/docs/DOC-9852

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

Opts::parse();
Opts::validate();
Util::connect();

my $host_view = Vim::find_entity_view(view_type => 'HostSystem'); 

&listVMs($host_view);

Util::disconnect();

sub listVMs {
	my ($host_view) = @_;

	my $vms = Vim::get_views(mo_ref_array => $host_view->vm, properties => ['name']);
 	foreach(@$vms) {
		my $vm_mo_ref_id = $_->{'mo_ref'}->value;

  		print "Virtual Machine: ".$_->{'name'}."\n";
		print "VMID: " . $vm_mo_ref_id . "\n";
		print "\n";
 	}
}
