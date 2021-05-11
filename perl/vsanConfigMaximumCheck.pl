#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://www.williamlam.com/2014/03/vsan-configuration-maximum-query-script.html

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;
use JSON qw(decode_json);

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
my %vsan_disk_group_result = ();
my %vsan_md_result = ();
my %vsan_ssd_result = ();
my %vsan_total_md_result = ();
my %vsan_component_result = ();
my $vsan_component_total_result = 0;
my $vsan_node_result = 0;
my %vsan_vm_per_host_result = ();
my $vsan_vm_per_cluster_result = 0;

# Config Maximums from https://www.vmware.com/pdf/vsphere5/r55/vsphere-55-configuration-maximums.pdf
my $vsan_disk_group_maximum = 5;
my $vsan_md_per_disk_group_maximum = 7;
my $vsan_ssd_per_disk_group_maximum = 1;
my $vsan_md_in_all_disk_group_maximum = 35;
my $vsan_component_maximum = 3000;
my $vsan_nodes_cluster_maximum = 32;
my $vsan_vm_per_host_maximum = 100;
my $vsan_vm_per_cluster_maxiumum = 3200;

# Retrieve vSphere VSAN Cluster
my $cluster_view = Vim::find_entity_view(view_type => 'ComputeResource', filter => { 'name' => $cluster}, properties => ['name','host']);
unless($cluster_view) {
	Util::disconnect();
	print "Error: Unable to find VSAN Cluster " . $cluster . "\n";
	exit 1;
}

print "Checking VSAN Configuration Maximums against " . $cluster_view->{'name'} . "\n";
my $hosts = Vim::get_views(mo_ref_array => $cluster_view->{'host'}, properties => ['name','configManager.vsanSystem','configManager.vsanInternalSystem','vm']);
foreach my $host(@$hosts) {
	# VSAN Managers
	my $vsanSys = Vim::get_view(mo_ref => $host->{'configManager.vsanSystem'});
	my $vsanIntSys = Vim::get_view(mo_ref => $host->{'configManager.vsanInternalSystem'});

	# retrieving VSAN Disk Group
	&get_vsan_disk_group_info($vsanSys,$host);

	# retrieving VSAN components on each host
	&get_vsan_component_info($vsanSys,$vsanIntSys,$host);

	# retrieving data about each VSAN host
	&get_vsan_host_info($host);

	# number of nodes in VSAN cluster
	$vsan_node_result += 1;
}

&print_results;

Util::disconnect();

sub get_vsan_disk_group_info {
	my ($vsanSys,$host) = @_;

	my $vsanDiskMappings = $vsanSys->config->storageInfo->diskMapping;
	my $total_mds = 0;
	foreach my $diskMapping(@$vsanDiskMappings) {
		my $mds = $diskMapping->nonSsd;
		$vsan_ssd_result{$host->{'name'}} = 1;
		$vsan_md_result{$host->{'name'}} = @$mds;
		$total_mds += @$mds;
	}
	$vsan_total_md_result{$host->{'name'}} = $total_mds;
	$vsan_disk_group_result{$host->{'name'}} = @$vsanDiskMappings;
}

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
			$vsan_component_total_result += $decoded{$key}{'lsom_objects_count'};
		}
	}
	$vsan_component_result{$host->{'name'}} = $component_count;
}

sub get_vsan_host_info {
	my ($host) = @_;

	my $vms = Vim::get_views(mo_ref_array => $host->{'vm'}, properties => ['name']);
	$vsan_vm_per_host_result{$host->{'name'}} = @$vms;
	$vsan_vm_per_cluster_result += @$vms;
}

sub print_results {
	print "\nVSAN Disk Groups Per Host (Max = " . $vsan_disk_group_maximum . ")\n";
	foreach my $key (sort keys %vsan_disk_group_result) {
		print "\t" . $key . "\t" . $vsan_disk_group_result{$key} . "\n";
	}

	print "\nMagnetic Disks Per Disk Group (Max = " . $vsan_md_per_disk_group_maximum . ")\n";
	foreach my $key (sort keys %vsan_md_result) {
		print "\t" . $key . "\t" . $vsan_md_result{$key} . "\n";
	}

	print "\nSSD Disks Per Disk Group (Max = " . $vsan_ssd_per_disk_group_maximum . ")\n";
	foreach my $key (sort keys %vsan_ssd_result) {
		print "\t" . $key . "\t" . $vsan_ssd_result{$key} . "\n";
	}

	print "\nTotal Magnetic Disks In All Disk Group Per Host (Max = " . $vsan_md_in_all_disk_group_maximum . ")\n";
	foreach my $key (sort keys %vsan_total_md_result) {
		print "\t" . $key . "\t" . $vsan_total_md_result{$key} . "\n";
	}

	print "\nComponents Per VSAN Host (Max = " . $vsan_component_maximum . ")\n";
	foreach my $key (sort keys %vsan_component_result) { 
		print "\t" . $key . "\t" . $vsan_component_result{$key} . "\n";
	}

	print "\nVSAN Nodes In A Cluster (Max = " . $vsan_nodes_cluster_maximum . ")\n";
	print "\t" .  "Total VSAN Nodes: " . $vsan_node_result . "\n";

	print "\nVMs Per Host (Max = " . $vsan_vm_per_host_maximum . ")\n";
	foreach my $key (sort keys %vsan_vm_per_host_result) {
		print "\t" . $key . "\t" . $vsan_vm_per_host_result{$key} . "\n";
	}

	print "\nVMs Per Cluster (Max = " . $vsan_vm_per_cluster_maxiumum . ")\n";
	print "\t" . "Total VMs: " . $vsan_vm_per_cluster_result . "\n";	

	print "\n";
}
