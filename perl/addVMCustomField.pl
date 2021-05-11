#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://communities.vmware.com/docs/DOC-10550

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
   key => {
      type => "=s",
      help => "Name of custom field",
      required => 1,
   },
   operation => {
      type => "=s",
      help => "Operation 'add' or 'update'",
      required => 1,
   },
   vmname => {
      type => "=s",
      help => "Name of VM to add/update custom field",
      required => 0,
   },
   value => {
      type => "=s",
      help => "Value of key",
      required => 0,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $cfkey = Opts::get_option('key');
my $value = Opts::get_option('value');
my $operation = Opts::get_option('operation');
my $vmname = Opts::get_option('vmname');

my $content = Vim::get_service_content();
my $customFieldMgr = Vim::get_view(mo_ref => $content->customFieldsManager);
my $fields = $customFieldMgr->field;

my $keyInt;
foreach(@$fields) {
	if($_->name eq $cfkey) {
		my $k = $_->key;
        	$keyInt = $k;
        }
}

my $success = 0;
if ( $operation eq 'add' ) {
	$customFieldMgr->AddCustomFieldDef(name => $cfkey, moType => 'VirtualMachine');
} elsif ( $operation eq 'update' ) {
	if($value eq '' || $vmname eq '') {
		print "\"--value\" & \"--vmname\" is required for an update!\n";
		exit 1
	}

	my $vm = Vim::find_entity_view(view_type => 'VirtualMachine',
                                      filter => {"config.name" => $vmname});
	unless ($vm) {
		print "Unable to find VM: \"$vmname\"!\n";
		exit 1
	}
	$customFieldMgr->SetField(entity => $vm, key => $keyInt, value => $value);
}

Util::disconnect();
