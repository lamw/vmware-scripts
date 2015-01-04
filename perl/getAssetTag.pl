#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://communities.vmware.com/docs/DOC-14652

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

Opts::parse();
Opts::validate();
Util::connect();

my $host_view = Vim::find_entity_view(view_type => 'HostSystem'); 
my $additional_vendor_info = "";

if($host_view->summary->hardware->otherIdentifyingInfo) {
	my $add_info = $host_view->summary->hardware->otherIdentifyingInfo;
	foreach (@$add_info) {
        	$additional_vendor_info .= $_->identifierType->key.": ".$_->identifierValue." ";
        }
	print $host_view->name . "\t" . $additional_vendor_info . "\n";
} else {
	print "There is no Asset/Service Tag information configured by your Vendor/OEM\n";
}

Util::disconnect();
