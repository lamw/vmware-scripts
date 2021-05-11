#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://www.williamlam.com/2014/03/exploring-vsan-apis-part-5-vsan-host-status.html

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;

# define custom options for vm and target host
my %opts = (
   'cluster' => {
      type => "=s",
      help => "Name of vSphere VSAN Cluster",
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

my $cluster_view = Vim::find_entity_view(view_type => 'ComputeResource', filter => { 'name' => $cluster});
unless($cluster_view) {
       	Util::disconnect();
       	print "Error: Unable to find vSphere Cluster " . $cluster . "\n";
       	exit 1;
}

my $host_views = Vim::get_views(mo_ref_array => $cluster_view->host, properties => ['name','configManager.vsanSystem']);
foreach my $host_view (@$host_views) {
	&getHostStatus($host_view);
}

Util::disconnect();

sub getHostStatus {
	my ($host) = @_;

	my $vsanSys = Vim::get_view(mo_ref => $host->{'configManager.vsanSystem'});

	my $vsanStatus;
	eval {
		$vsanStatus = $vsanSys->QueryHostStatus();
		print "Host: " . $host->name . "\n";
		print "Health: " . $vsanStatus->health . "\n";
		print "Node State: " . $vsanStatus->nodeState->state . "\n";
		print "Node UUID: " . $vsanStatus->nodeUuid . "\n";
		print "VSAN Cluster UUID: " . $vsanStatus->uuid . "\n\n"
	};
	if($@) {
		print "Error: " . $@ . "\n";
		Util:disconnect();
		exit 1;
	}
}
