#!/usr/bin/perl -w
# Copyright (c) 2009-2014 William Lam All rights reserved.

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
# www.virtuallyghetto.com

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;
use JSON qw(decode_json);

# define custom options for vm and target host
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

# Retrieve vSphere VSAN Cluster
my $cluster_view = Vim::find_entity_view(view_type => 'ComputeResource', filter => { 'name' => $cluster}, properties => ['name','host']);
unless($cluster_view) {
	Util::disconnect();
	print "Error: Unable to find VSAN Cluster " . $cluster . "\n";
	exit 1;
}

my $hosts = Vim::get_views(mo_ref_array => $cluster_view->{'host'}, properties => ['name','configManager.vsanSystem','configManager.vsanInternalSystem']);
foreach my $host(@$hosts) {
	# VSAN Managers
	my $vsanSys = Vim::get_view(mo_ref => $host->{'configManager.vsanSystem'});
	my $vsanIntSys = Vim::get_view(mo_ref => $host->{'configManager.vsanInternalSystem'});

	&get_vsan_component_info($vsanSys,$vsanIntSys,$host);
}

Util::disconnect();

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
		}
	}
	print "VSAN componenet count for " . $host->{'name'} . " = " . $component_count . "\n";
}
