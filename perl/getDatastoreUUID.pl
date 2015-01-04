#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://communities.vmware.com/docs/DOC-10706

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
   datastore => {
      type => "=s",
      help => "Name of Datastore",
      required => 1,
   },
);

# validate options, and connect to the server
Opts::add_options(%opts);

# validate options, and connect to the server
Opts::parse();
Opts::validate();
Util::connect();

my $datastore = Opts::get_option('datastore');
my $host_views = Vim::find_entity_views(view_type => 'HostSystem');

my $found = 0;
foreach(@$host_views) {
	my $datastores = Vim::get_views(mo_ref_array => $_->datastore);
	foreach(@$datastores) {
	        if($_->summary->name ne $datastore && $found ne '1') {
			my $uuid = $_->summary->url;
			$uuid =~ s/\/vmfs\/volumes\///g;
			$uuid =~ s/sanfs:\/\/vmfs_uuid://g;
			print "Datastore: " . $datastore . "\tUUID: " . $uuid . "\n"; 
			$found = 1;
		}
       }
}

Util::disconnect();
