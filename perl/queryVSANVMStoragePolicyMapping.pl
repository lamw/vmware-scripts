#!/usr/bin/perl -w
# Copyright (c) 2009-2013 William Lam All rights reserved.

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
#
# William Lam
# http://www.virtuallyghetto.com/

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;
use JSON qw(decode_json);

my %opts = (
   'vmname' => {
      type => "=s",
      help => "Name of VM consuming VSAN policy",
      required => 1,
   },
);

$SIG{__DIE__} = sub{Util::disconnect()};

# read and validate command-line parameters 
Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my @cmmds_queries;
my %disks_to_uuid_mapping;

my $vmname = Opts::get_option("vmname");

my $vm_view =  Vim::find_entity_view(view_type => 'VirtualMachine', filter => {'name' => $vmname}, properties => ['name','runtime.host','config.files','config.hardware.device']);

# Extract VM Home UUID from vmPath
my ($vm_dir,$vm_vmdk) = split('/',$vm_view->{'config.files'}->vmPathName,2);
my ($datastore,$vmhome_obj_uuid) = split(' ',$vm_dir,2);
$disks_to_uuid_mapping{$vmhome_obj_uuid} = "VM-Home";
print "\n" . $vmname . " Object UUIDs:\n\n";
print "VM-Home" . "\t\t" . $vmhome_obj_uuid . "\n";
my $vmhome_query = HostVsanInternalSystemCmmdsQuery->new(type => 'POLICY', uuid => $vmhome_obj_uuid);
push @cmmds_queries,$vmhome_query;

# Extract VM VMDK Object UUID
my $devices = $vm_view->{'config.hardware.device'};
foreach my $device (@$devices) {
	if($device->isa('VirtualDisk')) {
		if(defined($device->backing->backingObjectId)) {
			# Hash mapping so we can reference VMDK label later
			print $device->deviceInfo->label . "\t" . $device->backing->backingObjectId . "\n";
			$disks_to_uuid_mapping{$device->backing->backingObjectId} = $device->deviceInfo->label;
			my $disk_query = HostVsanInternalSystemCmmdsQuery->new(type => 'POLICY', uuid => $device->backing->backingObjectId);
			push @cmmds_queries,$disk_query;
		}
	}
}

# Access VSAN Internal Manager
my $host = Vim::get_view(mo_ref => $vm_view->{'runtime.host'}, properties => ['name','configManager.vsanInternalSystem']);
my $vsanIntSys = Vim::get_view(mo_ref => $host->{'configManager.vsanInternalSystem'});

my ($results,@decoded);
eval {
	print "\nIssuing VSAN CMMDS Query ...\n\n";
	$results = $vsanIntSys->QueryCmmds(queries => \@cmmds_queries);
	# Decode JSON
	@decoded = @{decode_json($results)->{'result'}};
};
if(@$) {
	print "Error: " . $@ . "\n";
	exit 1;
}

# Loop through JSON structure & extract VM Details + VM Storage Policies
foreach my $result (@decoded) {
	my $vm_object = $disks_to_uuid_mapping{$result->{"uuid"}};
	my $storagepolicy_id = $result->{"content"}->{"spbmProfileId"};
	my $stripe_width = ($result->{"content"}->{"stripeWidth"} ? $result->{"content"}->{"stripeWidth"} : "N/A");
	my $cache_reserv = ($result->{"content"}->{"cacheReservation"} ? $result->{"content"}->{"cacheReservation"} : "N/A");
	my $host_failure = ($result->{"content"}->{"hostFailuresToTolerate"} ? $result->{"content"}->{"hostFailuresToTolerate"} : "N/A");
	my $force_prov = ($result->{"content"}->{"forceProvisioning"} ? "TRUE" : "FALSE");
	my $obj_space_reserv = ($result->{"content"}->{"proportionalCapacity"} ? $result->{"content"}->{"proportionalCapacity"} : "N/A"); 	

	print "Name: " . $vm_object . " => VMStoragePolicyId: " . $storagepolicy_id . "\n";
	print "\tDiskStripesPerObject: " . $stripe_width . "\n";
	print "\tFlashCachReservation: " . $cache_reserv . "\n";
	print "\tHostFailureToTolerate: " . $host_failure . "\n";
	print "\tForceProvisioning: " . $force_prov . "\n";
	if(ref($obj_space_reserv)) {
		print "\tObjectSpaceReservation: " . join(',',@$obj_space_reserv) . "\n";
	} else {
		print "\tObjectSpaceReservation: " . $obj_space_reserv . "\n";
	}
	print "\n";
}

Util::disconnect();
