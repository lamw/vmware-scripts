#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://communities.vmware.com/docs/DOC-10282

use strict;
use warnings;
use VMware::VIRuntime;

my %opts = (
	vmname => {
	type => "=s",
	help => "Name of deleted VM to search for.",
	required => 1,
	},
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $vmname = Opts::get_option('vmname');
my $eventMgr = Vim::get_view(mo_ref => Vim::get_service_content()->eventManager);

my $events = $eventMgr->QueryEvents(filter => EventFilterSpec->new(type => ['VmRemovedEvent']));

foreach(@$events) {
	if ( $_->fullFormattedMessage =~ m/$vmname/i) { 
		print "User: ", $_->userName,"\n";
		print "Deleted VM: ", $_->fullFormattedMessage,"\n";
		print "Date/Time: ", $_->createdTime,"\n\n";
	}
}

Util::disconnect();
