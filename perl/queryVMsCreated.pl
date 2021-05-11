#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://communities.vmware.com/docs/DOC-10773

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;

########### NOT MODIFY PAST HERE ###########

# validate options, and connect to the server
Opts::parse();
Opts::validate();
Util::connect();

my $content = Vim::get_service_content();
my $eventMgr = Vim::get_view(mo_ref => $content->eventManager);

my ($msg,$time,$user);
format = 
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<| @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<| @<<<<<<<<<<<<<<<<<<<<
$msg,				$time,			    			$user				
.

$msg = "VM";
$time = "TIME";
$user = "USERNAME";
write;

eval {
	my $filterSpec = EventFilterSpec->new(type => ["VmCreatedEvent","VmCloneEvent","VmDeployedEvent"]);
	my $events = $eventMgr->QueryEvents(filter => $filterSpec);
	foreach(@$events) {
		$msg = $_->fullFormattedMessage;
		$time = $_->createdTime;
		$user = $_->userName;
		write;	
	}
};
if($@) {
	print "Error: " . $@ . "\n";
}

Util::disconnect();
