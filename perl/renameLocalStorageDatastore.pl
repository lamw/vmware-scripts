#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://communities.vmware.com/docs/DOC-10571

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;
use VMware::VIExt;

my %opts = (
   cluster => {
      type => "=s",
      help => "Name of Cluster to search",
      required => 1,
   },
   jk_mode => {
      type => "=s",
      help => "[0|1] Prints out what the new Datastores would be renamed to but don't modify",
      required => 1,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $cluster = Opts::get_option('cluster');
my $jk_mode = Opts::get_option('jk_mode');
my ($cluster_view,$host_views,$vms);

$cluster_view = Vim::find_entity_view(view_type => 'ClusterComputeResource', filter => { name => $cluster});

unless($cluster_view) {
	die "Unable to locate cluster name \"$cluster\"!";
}

print "This could take a few minutes depending on the size of the cluster ...\n\n";

print "Cluster: " . $cluster_view->name . "\n";
if($jk_mode eq '1') {
print "Just Kidding Mode ENABLED! - Will not rename datastores but display what it would be renamed to\n\n";
}
$host_views = Vim::get_views(mo_ref_array => $cluster_view->host);
foreach(@$host_views) {
	my $hostName = $_->name;
	my $shortHostName;
	
	my $networkSys = Vim::get_view(mo_ref => $_->configManager->networkSystem);
	if(defined($networkSys->dnsConfig)) {
		#if localhost .. SA failed! use FQDN or long hostname
		if($networkSys->dnsConfig->hostName eq 'localhost') {
			$shortHostName = $hostName;
		} else {
			$shortHostName = $networkSys->dnsConfig->hostName; 
		}
	} else {
		$shortHostName = $hostName;
	}

	print "\tHost: " . $hostName . "\n";
	my $datastores = Vim::get_views(mo_ref_array => $_->datastore);
	my $numOfLocalStorageOnHost = 0;
	foreach(@$datastores) {
		if($_->summary->multipleHostAccess == 0) {
			$numOfLocalStorageOnHost += 1;
			print "\t\tLocalstorage: " . $_->summary->name . "\n";
			my $renameDSName = $shortHostName . "-local-storage-" . $numOfLocalStorageOnHost;
			print "\t\tRename to: [" . $renameDSName . "]\n";
			if($jk_mode eq '0') {
				$_->RenameDatastore(newName => $renameDSName);	
			}
		}
	}
	print "\tTotal # of local datastores on host: " . $numOfLocalStorageOnHost . "\n\n";
}

Util::disconnect();
