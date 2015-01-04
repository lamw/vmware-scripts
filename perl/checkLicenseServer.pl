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

#first query License Server from vCenter
my $content = Vim::get_service_content();
if($content->about->apiType ne 'VirtualCenter') {
	print "Please input a valid vCenter hostname/IP for --server\n";
	Util::disconnect();
	exit 1;
}

my $lic_mgr = Vim::get_view(mo_ref => $content->licenseManager);
print "Checking License Server: ", $lic_mgr->source->licenseServer,"\n";
print "License Source availability ", $lic_mgr->sourceAvailable,"\n"; 

if($lic_mgr->sourceAvailable eq 'true') {
	my ($hosts, $host, @host_wo_lic);

	$hosts = Vim::find_entity_views(view_type => 'HostSystem');

	unless (defined $hosts){
		print "No hosts found.\n";	
		exit 0;
	}

	print "Querying hosts ...\n";
	foreach $host(@{$hosts}) {
		my $host_serv_content =  Vim::get_service_content();
		my $host_lic_mgr =  Vim::get_view(mo_ref => $content->licenseManager);
		if($host_lic_mgr->sourceAvailable eq 'false') {
			push @host_wo_lic, $host->name;
		}
	}
	if(@host_wo_lic) {
		foreach (@host_wo_lic) {
			print $_, " does not have valid license source\n";
		}
	} else {
		print "All hosts are licensed!\n";
	}
} else {
	print "License Server is down!\n";
}
Util::disconnect();
