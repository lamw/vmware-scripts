#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://www.williamlam.com/2014/04/exploring-vsan-apis-part-9-vsan-component-count.html

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;
use JSON qw(decode_json);

# define custom options for vm and target host
my %opts = (
		'cluster' => {
			type => "=s",
			help => "Name of VSAN Cluster",
			required => 1,
		},
);

$SIG{__DIE__} = sub{Util::disconnect()};

# read and validate command-line parameters 
Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $cluster = Opts::get_option("cluster");

# Retrieve vSphere VSAN Cluster
my $cluster_view = Vim::find_entity_view(view_type => 'ComputeResource', filter => { 'name' => $cluster}, properties => ['name','host']);
unless($cluster_view) {
	Util::disconnect();
	print "Error: Unable to find VSAN Cluster " . $cluster . "\n";
	exit 1;
}

my $hosts = Vim::get_views(mo_ref_array => $cluster_view->{'host'}, properties => ['name','configManager.vsanSystem','configManager.vsanInternalSystem']);
foreach my $host(@$hosts) {
	# VSAN Managers
	my $vsanSys = Vim::get_view(mo_ref => $host->{'configManager.vsanSystem'});
	my $vsanIntSys = Vim::get_view(mo_ref => $host->{'configManager.vsanInternalSystem'});

	&get_vsan_component_info($vsanSys,$vsanIntSys,$host);
}

Util::disconnect();

sub get_vsan_component_info {
	my ($vsanSys,$vsanIntSys,$host) = @_;

	my $results = $vsanIntSys->QueryPhysicalVsanDisks(props => ['lsom_objects_count','owner']);
	my $vsanStatus = $vsanSys->QueryHostStatus();

	# Decode JSON
	my %decoded = %{decode_json($results)};

	my $component_count = 0;
	foreach my $key (sort keys %decoded) {
		# ensure component is owned by ESXi host
		if($decoded{$key}{'owner'} eq $vsanStatus->nodeUuid) {
			$component_count += $decoded{$key}{'lsom_objects_count'};
		}
	}
	print "VSAN componenet count for " . $host->{'name'} . " = " . $component_count . "\n";
}
