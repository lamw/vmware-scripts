#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://communities.vmware.com/docs/DOC-11910

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
   file => {
      type => "=s",
      help => "Message to display on the DCUI",
      required => 1,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $key = 'Annotations.WelcomeMessage';
my $file = Opts::get_option('file');

open FILE, "<$file";
my $value = do { local $/; <FILE> };

my $host = Vim::find_entity_view(view_type => 'HostSystem');
my $advOpt = Vim::get_view(mo_ref => $host->configManager->advancedOption);

my $adv_param = OptionValue->new(key => $key, value => $value);

eval {
	print "Updating \"" . $host->name . "\" with advanced parameter configuration: \"$key\" with value:\n$value";
	$advOpt->UpdateOptions(changedValue => [$adv_param]);
};
if($@) {
	print "Error: " . $@ . "\n";
}

Util::disconnect();
