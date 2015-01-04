#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
        cluster => {
        type => "=s",
        help => "The name of a vCenter cluster",
        required => 1,
        },
);

# validate options, and connect to the server
Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $cluster_name = Opts::get_option('cluster');

my $cluster_view = Vim::find_entity_view(view_type => 'ClusterComputeResource', filter => { name => $cluster_name });

unless (defined $cluster_view){
        print "No cluster found with name $cluster_name!\n";
	Util::disconnect();
	exit 1;
}

my $envBrowser = Vim::get_view(mo_ref => $cluster_view->environmentBrowser);

eval {
	my $virtualHWs = $envBrowser->QueryConfigOptionDescriptor();
	foreach my $vhw (@$virtualHWs) {
		if($vhw->runSupported) {
			print $vhw->key . " -- " . $vhw->description . "\n";
		}
	}
};
if($@) {
	print "Error: " . $@ . "\n";
}

Util::disconnect();
