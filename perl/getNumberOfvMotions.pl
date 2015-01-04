#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://www.virtuallyghetto.com/2012/04/auditing-vmotion-migrations.html

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;

my %opts = (
   vmname => {
      type => "=s",
      help => "Name of Virtual Machine to query number of vMotions",
      required => 1,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $vmname = Opts::get_option('vmname');
my %vmotions = ();
my $numvMotions = 0;

my $eventMgr = Vim::get_view(mo_ref => Vim::get_service_content()->eventManager);
my $vm_view = Vim::find_entity_view(view_type => 'VirtualMachine', filter => {"name" => $vmname});

unless($vm_view) {
	print "Unable to locate VM: " . $vmname . "\n";
	Util::disconnect();
	exit 1;
}

eval {
	my $recursion = EventFilterSpecRecursionOption->new("self");
	my $entity = EventFilterSpecByEntity->new(entity => $vm_view, recursion => $recursion);
	my $filterSpec = EventFilterSpec->new(type => ["VmMigratedEvent"], entity => $entity);
	my $events = $eventMgr->QueryEvents(filter => $filterSpec);
	$numvMotions = @$events;
	foreach(@$events) {
		if(defined($_->host)) {
			$vmotions{$_->host->name} += 1;
		}
	}
};
if($@) {
	print "Error: " . $@ . "\n";
}

print "\n" . $vmname . " has a total of " . $numvMotions . " vMotions:\n\n";
for my $key ( sort keys %vmotions ) {
        my $value = $vmotions{$key};
        print "$key => $value\n";
}
print "\n";

Util::disconnect();
