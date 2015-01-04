#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;

Opts::parse();
Opts::validate();
Util::connect();

# Query ESXi 5.0 hosts only
my $hosts = Vim::find_entity_views(
	view_type => 'HostSystem',
	filter => {
		'summary.config.product.version' => '5.0.0'
	},
	properties => ['name'],
);

foreach(@$hosts) {
	print $_->{'name'} . "\n";
}	

Util::disconnect();
