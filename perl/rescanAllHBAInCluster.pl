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
# http://communities.vmware.com/docs/DOC-10187

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
