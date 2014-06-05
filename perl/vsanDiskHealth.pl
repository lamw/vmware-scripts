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
