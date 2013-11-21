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
# http://communities.vmware.com/docs/DOC-10220
# Sydnicated from: http://communities.vmware.com/message/1288452#1288452

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
