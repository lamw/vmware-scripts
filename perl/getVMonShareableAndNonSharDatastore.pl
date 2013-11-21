#!/usr/bin/perl -w
# Copyright (c) 2009-2010 William Lam All rights reserved.

# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. The name of the author or contributors may not be used to endorse or
#    promote products derived from this software without specific prior
#    written permission.
# 4. Consent from original author prior to redistribution

# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

# William Lam 
# 08/14/09
# http://communities.vmware.com/docs/DOC-10552
# http://engineering.ucsb.edu/~duonglt/vmware

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
   type => {
      type => "=s",
      help => "[cluster|datacenter|all]",
      required => 1,
   },
   cluster => {
      type => "=s",
      help => "Name of Cluster to search",
      required => 0,
   },
   datacenter => {
      type => "=s",
      help => "Name of Datacenter to search",
      required => 0,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $type = Opts::get_option('type');
my $cluster = Opts::get_option('cluster');
my $datacenter = Opts::get_option('datacenter');
my @nonshared_datastores;
my ($cluster_view,$datacenter_views,$datacenter_view,$datastores,$vms);

if($type eq 'all') {
	$datacenter_views = Vim::find_entity_views(view_type => 'Datacenter');

	# loop de loop
	foreach(@$datacenter_views) {
		print "Datacenter: " . $_->name . "\n";
		$datastores = Vim::get_views(mo_ref_array => $_->datastore);
		printDatastore($datastores);
	}
} elsif($type eq 'datacenter' && $datacenter ne '') {
	$datacenter_view = Vim::find_entity_view(view_type => 'Datacenter', filter => { name => $datacenter});
	unless($datacenter_view) {
		print "Error: unable to locate Datacenter: \"$datacenter\"!\n";
		exit 1
	}
	print "Datacenter: " . $datacenter_view->name . "\n";	
	$datastores = Vim::get_views(mo_ref_array => $datacenter_view->datastore);
	&printDatastore($datastores);
} elsif($type eq 'cluster' || $cluster ne '') {
	$cluster_view = Vim::find_entity_view(view_type => 'ClusterComputeResource', filter => { name => $cluster});
	print "Cluster: " . $cluster_view->name . "\n";
	$datastores = Vim::get_views(mo_ref_array => $cluster_view->datastore);
        &printDatastore($datastores);
} else {
	print "Ensure if you're using --type [datacenter|cluster], that you specify --cluster or --datacenter object\n";
	exit 1
}


sub printDatastore {
		my ($datastores) = @_;
		print "\tShared Datastores:\n";
		foreach(@$datastores) {
			# only care about VMFS + shared access
			# FC SAN VMFS
			if($_->summary->type eq 'VMFS' && $_->summary->multipleHostAccess == 1) {
				$vms = Vim::get_views(mo_ref_array => $_->vm, properties => ['name']);
				print "\t\tDatastore: [" . $_->summary->name . "]" . " is " . $_->summary->type . " with: " . scalar(@$vms) . " VMs\n";
			# NFS
			} elsif($_->summary->type eq 'NFS' && $_->summary->multipleHostAccess == 1) {
				$vms = Vim::get_views(mo_ref_array => $_->vm, properties => ['name']);
                                print "\t\tDatastore: [" . $_->summary->name . "]" . " is " . $_->summary->type . " with: " . scalar(@$vms) . " VMs\n";
			# not shared
			} else {
				$vms = Vim::get_views(mo_ref_array => $_->vm, properties => ['name']);
				my $ds_string = "\t\tDatastore: [" . $_->summary->name . "]" . " is " . $_->summary->type . " with: " . scalar(@$vms) . " VMs\n";
				foreach(@$vms) {
					$ds_string .= "\t\t\t" . $_->{'name'} . "\n";
				}
				push @nonshared_datastores, $ds_string;
			}
		}
		print "\n\tNon-Shared Datastores:\n";
	        foreach(@nonshared_datastores) {
        	        print $_;
        	}
		print "\n";
}
Util::disconnect();
