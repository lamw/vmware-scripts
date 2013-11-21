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
# 4. Written Consent from original author prior to redistribution

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

# William Lam 11/28/09
# http://communities.vmware.com/docs/DOC-11448
# http://engineering.ucsb.edu/~duonglt/vmware

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
