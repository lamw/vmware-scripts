#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://communities.vmware.com/docs/DOC-11054

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;
use Term::ANSIColor;

my ($cluster_views,$vmname,$vm_view,$host_view,$hostname);

my %opts = (
	cluster => {
	type => "=s",
        help => "Name of the vCenter cluster",
	required => 0,
	},
);

# validate options, and connect to the server
Opts::add_options(%opts);

# validate options, and connect to the server
Opts::parse();
Opts::validate();
Util::connect();

my $cluster = Opts::get_option('cluster');

my ($cluster_view,$node,$config_state,$runtime_state);

if(defined($cluster)) {
	$cluster_view = Vim::find_entity_view(view_type => 'ClusterComputeResource', filter => { name => $cluster });
	unless ($cluster_view){
		Util::disconnect();
		die "No cluster found with name $cluster\n";	
	}
	&getHANodes($cluster_view);
} else {
	$cluster_view = Vim::find_entity_views(view_type => 'ClusterComputeResource');
	foreach(sort {$a->name cmp $b->name} @$cluster_view) {
		&getHANodes($_);
	}
}

Util::disconnect();

sub getHANodes {
	my ($cluster) = @_;

	print color("yellow") . "Cluster: " . $cluster->name . color("reset") . "\n"; 
	my $cluster_info = $cluster->RetrieveDasAdvancedRuntimeInfo();
	my $prim_hosts = $cluster_info->dasHostInfo->primaryHosts;
	print "\t" . color("green") . "HA Primary Nodes: " .  color("reset") . "\n";
	foreach(@$prim_hosts) {
		print "\t\t" . $_ . "\n";
	}

	print "\t" . color("green") . "HA Node States: " .  color("reset") . "\n";
	print "\t\tNode Name\t\tNode Config State\t\tNode Runtime State\n";
	print "\t\t------------------------------------------------------------------------------\n";	
	my $host_states = $cluster_info->dasHostInfo->hostDasState;
	foreach(@$host_states) {
		($node,$config_state,$runtime_state) = ($_->name,$_->configState,$_->runtimeState);
		print "\t\t" . $node . "\t\t" . $config_state . "\t\t\t" . $runtime_state . "\n";
	}
	print "\n";
}
