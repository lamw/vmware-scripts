#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://communities.vmware.com/docs/DOC-10187

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

my ($cluster_view, $cluster_name, $host, $hosts);

my %opts = (
	cluster => {
      	type => "=s",
      	help => "The name of a vCenter cluster to rescan all HBA",
      	required => 0,
   	},
	host => {
        type => "=s",
        help => "The name of a single ESX(i) host to rescan HBA",
	required => 0,
	},
);

# validate options, and connect to the server
Opts::add_options(%opts);

# validate options, and connect to the server
Opts::parse();
Opts::validate();
Util::connect();

if ( Opts::option_is_set('cluster') ) {
	$cluster_name = Opts::get_option('cluster');
	$cluster_view = Vim::find_entity_view(view_type => 'ClusterComputeResource', filter => { name => $cluster_name });
	unless (defined $cluster_view){
        	die "No clusters found.\n";
	}
	$hosts = Vim::get_views (mo_ref_array => $cluster_view->host);
} elsif ( Opts::option_is_set('host') ) {
	$host = Opts::get_option('host');
	my $host_view = Vim::find_entity_view(view_type => 'HostSystem', filter => { name => $host });
	unless (defined $host_view){
                die "No clusters found.\n";
        }
	my @hostArr = ();
	push @hostArr, $host_view;
	$hosts = \@hostArr;
} else {
	print "\nPlease either define a --cluster or --host to rescan!\n";
}


if(defined $hosts) {
	if($cluster_name) {
		print "Scanning cluster: ", $cluster_name," ...\n";
	} else {
		print "Scanning host: ", $host," ...\n";
	}

	foreach(@$hosts) {
		my $storageSystem = Vim::get_view(mo_ref => $_->configManager->storageSystem);

		#rescan all hba
		eval {
			$storageSystem->RescanAllHba();
		};
		if($@) { 
			print "\tRescan all HBAs failed for host ", $_->name, ".\n";
		} else {
			print "\tRescan all HBAs successful for host ", $_->name, ".\n";
		}
		#rescan for new VMFS volumes
		eval {
                        $storageSystem->RescanVmfs();
                };
		if($@) {
                        print "\tRescan for new VMFS volumes failed for host ", $_->name, ".\n";
                } else {
                        print "\tRescan for new VMFS volumes successful for host ", $_->name, ".\n";
                }
		#refresh storage info
		eval {
                        $storageSystem->RefreshStorageSystem();
                };
                if($@) {
                        print "\tRefresh storage information failed for host ", $_->name, ".\n";
                } else {
                        print "\tRefresh storage information successful for host ", $_->name, ".\n";
                }	
	}
	if($cluster_name) {
		print "Scanning cluster complete!\n";
	} else {
		print "Scanning host complete!\n";
	}
}

Util::disconnect();
