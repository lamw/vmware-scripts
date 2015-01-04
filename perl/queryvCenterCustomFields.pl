#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

Opts::parse();
Opts::validate();
Util::connect();

my $content = Vim::get_service_content();
my $customFieldMgr = Vim::get_view(mo_ref => $content->customFieldsManager);

my %field_key;
if ( defined $customFieldMgr->field ) {
	foreach (@{$customFieldMgr->field}) {
        	$field_key{$_->key} = $_->name;
        }
}

my $host_views = Vim::find_entity_views(view_type => 'HostSystem', properties => ['name','customValue']);
foreach my $host (@$host_views) {
	if(defined($host->{'customValue'})) {
		my $customFields = $host->{'customValue'};
		foreach(@$customFields) {
			print ref($host) . "\t" . $host->{'name'} . "\t" . $field_key{$_->key} . "\t" . $_->value . "\n";
		}
	}
}

my $vm_views = Vim::find_entity_views(view_type => 'VirtualMachine', properties => ['name','customValue']);
foreach my $vm (@$vm_views) {
        if(defined($vm->{'customValue'})) {
                my $customFields = $vm->{'customValue'};
                foreach(@$customFields) {
                        print ref($vm) . "\t" . $vm->{'name'} . "\t" . $field_key{$_->key} . "\t" . $_->value . "\n";
                }
        }
}


Util::disconnect();
