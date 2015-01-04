#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://www.virtuallyghetto.com/2011/11/vsphere-moref-managed-object-reference.html

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
