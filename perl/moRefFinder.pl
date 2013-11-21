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
# http://www.virtuallyghetto.com/

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
        type => {
        type => "=s",
        help => "vm|host|cluster|datacenter|rp|network|dvs|folder|vapp|datastore",
        required => 1,
        },
	name => {
        type => "=s",
        help => "Name of vCenter entityt to query for MoRef ID",
	required => 1,
        },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $type = Opts::get_option('type');
my $name = Opts::get_option('name');

my %entityMapping = (
	'vm' => 'VirtualMachine',
	'host' => 'HostSystem',
	'cluster' => 'ComputeResource',
	'datacenter' => 'Datacenter',
	'rp' => 'ResourcePool',
	'network' => 'Network',
	'dvs' => 'DistributedVirtualSwitch',
	'folder' => 'Folder',
	'vapp' => 'ResourcePool',
	'datastore' => 'Datastore'
);

&getMoRef($type,$name);

Util::disconnect();

sub getMoRef {
	my ($type,$name) = @_;

	if(!$entityMapping{$type}) {
                print "Error: Invalid Entity Type: $type\n";
                Util::disconnect();
                exit 1;
        }

	my $entity = Vim::find_entity_view(view_type => $entityMapping{$type}, filter => {"name" => $name}, properties => ['name']);
	if(Vim::get_service_content()->about->apiType eq "VirtualCenter") {
		print "\nvCenterInstanceUUID: " . Vim::get_service_content()->about->instanceUuid . "\n";
	}
	print "EntityName: " . $entity->{'name'} . "\t MoRefID: " . $entity->{'mo_ref'}->value . "\n\n";
}


sub listVMs {
	my ($host_view) = @_;

	my $vms = Vim::get_views(mo_ref_array => $host_view->vm, properties => ['name']);
 	foreach(@$vms) {
		my $vm_mo_ref_id = $_->{'mo_ref'}->value;

  		print "Virtual Machine: ".$_->{'name'}."\n";
		print "VMID: " . $vm_mo_ref_id . "\n";
		print "\n";
 	}
}
