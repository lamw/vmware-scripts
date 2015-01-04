#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://www.virtuallyghetto.com/2014/03/required-esxi-advanced-setting-to-support-16-node-vsan-cluster.html

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
	cluster => {
	type => "=s",
	help => "Name of Cluster to create Alarm on",
	required => 1,
	},
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $cluster = Opts::get_option('cluster');

my $cluster_view = Vim::find_entity_view(view_type => 'ClusterComputeResource', filter => {'name' => $cluster}, properties => ['name','host']);
my $hosts = Vim::get_views(mo_ref_array => $cluster_view->{'host'}, properties => ['name','configManager.advancedOption']);

unless($cluster_view) {
	Util::disconnect();
	print "Unable to find Cluster " . $cluster . "\n";
	exit 1;
}

foreach my $host (@$hosts) {
	my $advConfigurations = Vim::get_view(mo_ref => $host->{'configManager.advancedOption'});
	my $value = new PrimType(1,"long");
	my $option = OptionValue->new(key => "CMMDS.goto11", value => $value);
	print "Configuring " . $host->{'name'} . " to support participation in 16+ VSAN Node Cluster\n";
	eval {	
		$advConfigurations->UpdateOptions(changedValue => [$option]);
	};
	if($@) {
		print "Error: " . $@ . "\n";
	}
}

Util::disconnect();
