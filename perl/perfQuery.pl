#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://www.virtuallyghetto.com/2010/10/where-are-power-perf-metrics-in-vsphere.html

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;

my %opts = (
        'type' => {
        type => "=s",
        help => "Performance Metric Type [clusterServices|cpu|managementAgent|mem|net|rescpu|datastore|disk|virtualDisk|storageAdapter|storagePath|sys|vmop|power|vcResources|vcDebugInfo]",
        required => 0,
	default => "all",
        },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $type = Opts::get_option("type");
my $content = Vim::get_service_content();		
my $perfMgr = Vim::get_view(mo_ref => $content->perfManager);

my $perfCounter = $perfMgr->perfCounter;

foreach(@$perfCounter) {
	if($type eq "all" || $_->groupInfo->key eq $type) {
		print "Metric Name: " . $_->rollupType->val . "." . $_->unitInfo->key . "." . $_->nameInfo->key . "\n";
		print "Metric Type: " . $_->groupInfo->key . "\n";
                print "Metric ID  : " . $_->key . "\n";
                print "Metric Stat: " . $_->statsType->val . "\n";
                print "Metric Desc: " . $_->nameInfo->summary . "\n\n";
	}
}

Util::disconnect();
