#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://communities.vmware.com/docs/DOC-11448

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
	cluster => {
        type => "=s",
        help => "Name of Cluster",
	required => 1,
        },
	resourcepool  => {
        type => "=s",
        help => "Name of Resource Pool to create",
	required => 1,
        },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my ($folder, $resourcepool, $cluster, $clusterView, $clusterRootResourcePool);

$resourcepool = Opts::get_option('resourcepool');
$cluster = Opts::get_option('cluster');

$clusterView = Vim::find_entity_view(view_type => 'ClusterComputeResource', filter => { name => $cluster});

unless($clusterView) {
        Util::disconnect();
        die "Unable to locate Cluster: \"$cluster\"\n";
}

$clusterRootResourcePool = Vim::get_view(mo_ref => $clusterView->resourcePool);

eval {
	my $sharesLevel = SharesLevel->new('normal');
	my $cpuShares = SharesInfo->new(shares => 4000, level => $sharesLevel);
	my $memShares = SharesInfo->new(shares => 163840, level => $sharesLevel);
	my $cpuAllocation = ResourceAllocationInfo->new(expandableReservation => 'true', limit => -1, reservation => 0, shares => $cpuShares);
	my $memoryAllocation = ResourceAllocationInfo->new(expandableReservation => 'true', limit => -1, reservation => 0, shares => $memShares);
	my $rp_spec = ResourceConfigSpec->new(cpuAllocation => $cpuAllocation, memoryAllocation => $memoryAllocation);
	my $newRP = $clusterRootResourcePool->CreateResourcePool(name => $resourcepool, spec => $rp_spec);

	if($newRP->type eq 'ResourcePool') {
		print "Successfully created new ResourcePool: \"" . $resourcepool . "\"\n";
	} else {
		print "Error: Unable to create new ResourcePool: \"" . $resourcepool . "\"\n";
	}
};
if($@) { print "Error: " . $@ . "\n"; }

Util::disconnect();
