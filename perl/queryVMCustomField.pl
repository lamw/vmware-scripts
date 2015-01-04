#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://communities.vmware.com/docs/DOC-10220

use strict;
use warnings;

use VMware::VIRuntime;

my %opts = (
	vmname => {
	type => "=s",
	variable => "VMNAME",
	help => "Name of virtual machine.",
	required => 1,
	},
	
	customfield => {
	type => "=s",
	variable => "CUSTOMFIELD",
	help => "Name of a custom field to retrieve a value from.",
	require => 1,
	},
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();

Util::connect();

my ($vm_view, $vm_name, $custom_field, $customFieldsMgr, $sc);

$vm_name = Opts::get_option("vmname");
$custom_field = Opts::get_option("customfield");

$vm_view = Vim::find_entity_view( 
	view_type => "VirtualMachine",
	filter => { 'name' => $vm_name },
	properties => [ 'name', 'summary' ],
);

unless ( defined $vm_view ) {
	die "Virtual Machine, '$vm_name', not found.\n";
}

$sc = Vim::get_service_content();
$customFieldsMgr = Vim::get_view( mo_ref => $sc->customFieldsManager );

unless ( (defined $vm_view->summary) && defined($vm_view->summary->customValue) ) {
	print "No custom values defined for virtual machine, '$vm_name'.\n";
}
else {
	# Get the field key value from the supplied custom field name
	my $field_key = undef;
	if ( defined $customFieldsMgr->field ) {
		foreach (@{$customFieldsMgr->field}) {
			if ( $_->name eq $custom_field ) {
				$field_key = $_->key;
			}
		}
	}

	unless ( defined $field_key ) {
		die "No custom field named '$custom_field' found.\n";
	}

	my ($value, $key);
	foreach ( @{$vm_view->summary->customValue} ) {
		$key = $_->key;
		$value = $_->value;
	
		if ( $key eq $field_key ) {
			print "Virtual Machine: $vm_name\n";
			print "   $custom_field = $value\n";
		}
	}
}

Util::disconnect();
