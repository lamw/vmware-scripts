#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://www.virtuallyghetto.com/2012/02/automating-vcenter-server-advanced.html

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
   operation => {
      type => "=s",
      help => "Operation [list|update",
      required => 1,
   },
   key => {
      type => "=s",
      help => "Name of advanced setting",
      required => 0,
   },
   value => {
      type => "=s",
      help => "Value to change advanced setting",
      required => 0,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $operation = Opts::get_option('operation');
my $key = Opts::get_option('key');
my $value = Opts::get_option('value');

my $sc = Vim::get_service_content();
my $settingMgr = Vim::get_view(mo_ref => $sc->setting);

if($sc->about->productLineId ne "vpx") {
	print "This is only supported on a vCenter Server\n\n";
	Util::disconnect();
	exit 1;
}

if($operation eq "list") {
	my $settings = $settingMgr->setting;
	foreach(sort {$a->key cmp $b->key} @$settings) {
		print $_->key . " = " . $_->value . "\n";
	}
} elsif($operation eq "update") {
	unless($key && $value) {
		print "\"update\" operation requires both \"key\" and \"value\"\n\n";
		Util::disconnect();
	        exit 1;
	}
	print "Updating \"$key\" to \"$value\" ...\n";
	eval {
		my $option = OptionValue->new(key => $key, value => $value);
		$settingMgr->UpdateOptions(changedValue => [$option]);
		print "\tSuccessfully updated advanced setting\n";
	};
	if($@) {
		print "Error: " . $@ . "\n";
	}
} else  {
	print "Invalid option\n";
}

Util::disconnect();
