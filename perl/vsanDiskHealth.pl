#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://www.williamlam.com/2014/06/exploring-vsan-apis-part-10-vsan-disk-health.html

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;
use JSON qw(decode_json);

my %opts = (
		'cluster' => {
			type => "=s",
			help => "Name of VSAN Cluster",
			required => 0,
		},
);

$SIG{__DIE__} = sub{Util::disconnect()};

# read and validate command-line parameters 
Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $cluster = Opts::get_option("cluster");
# Disk Health Codes
my %health_satus = (0,'OK',4,'Failed',5,'OFFLINE',6,'DECOMISSIONED');

# Retrieve vSphere VSAN Cluster
my $cluster_view = Vim::find_entity_view(view_type => 'ComputeResource', filter => { 'name' => $cluster}, properties => ['name','host','configurationEx']);
unless($cluster_view) {
	Util::disconnect();
	print "Error: Unable to find VSAN Cluster " . $cluster . "\n";
	exit 1;
}

my %vsanDiskUUIDMapping = ();
my $hosts = Vim::get_views(mo_ref_array => $cluster_view->{'host'}, properties => ['name','configManager.vsanSystem','configManager.vsanInternalSystem']);
	foreach my $host(@$hosts) {
	# VSAN Managers
	my $vsanSys = Vim::get_view(mo_ref => $host->{'configManager.vsanSystem'});
	my $vsanIntSys = Vim::get_view(mo_ref => $host->{'configManager.vsanInternalSystem'});

	# map VSAN UUID to Disk Identifer (naa*)
	&get_vsan_disk_uuid_mapping($vsanSys);
	# retrieve disk health info
	&get_vsan_disk_health_info($vsanSys,$vsanIntSys,$host);
}

Util::disconnect();

sub get_vsan_disk_health_info {
	my ($vsanSys,$vsanIntSys,$host) = @_;
	my $results = $vsanIntSys->QueryPhysicalVsanDisks(props => ['owner','uuid','isSsd','capacity','capacityUsed','disk_health']);
	my $vsanStatus = $vsanSys->QueryHostStatus();

	# Decode JSON
	my %decoded = %{decode_json($results)};

	print "===================================\n" . $host->{'name'} . "\n\n";
	foreach my $key (sort keys %decoded) {
		# ensure device is owned by ESXi node
		if($decoded{$key}{'owner'} eq $vsanStatus->nodeUuid) {
			print "Device: " . $vsanDiskUUIDMapping{$decoded{$key}{'uuid'}} . "\n";
      		print "VSANUUID: " . $decoded{$key}{'uuid'} . "\n";
      		print "SSD: " . ($decoded{$key}{'isSsd'} ? "True" : "False") . "\n";
      		print "Capacity: " . $decoded{$key}{'capacity'} . "\n";
      		print "CapacityUsed: " . $decoded{$key}{'capacityUsed'} . "\n";
			print "DiskHealh: " . $health_satus{$decoded{$key}{'disk_health'}{'healthFlags'}} . "\n\n";
		}
	}
}

sub get_vsan_disk_uuid_mapping {
	my ($vsanSys) = @_;

	my $vsanDisks = $vsanSys->QueryDisksForVsan();

	foreach my $vsanDisk (@$vsanDisks) {
		$vsanDiskUUIDMapping{$vsanDisk->vsanUuid} = $vsanDisk->disk->canonicalName;
	}
}
