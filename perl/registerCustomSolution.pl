#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://www.williamlam.com/2011/09/how-to-use-custom-vm-icons-in-vsphere-5.html

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

###########################
## PLEASE EDIT SCRIPT     #
## AND CHANGE VALUE FROM  #
## FROM 0 TO 1 WHEN READY #
## PRIOR TO RUNNING       #
###########################
my $editedScript = 0;

if(!$editedScript) {
	print "\nYou did not follow directions, please edit the script to fit your environment before running!\n";
	exit 1;
}


Opts::parse();
Opts::validate();
Util::connect();

unless(Vim::get_service_content()->about->apiVersion eq "5.0" && Vim::get_service_content()->about->productLineId eq "vpx") {
        print "vSphere Solutions is only supported with vSphere vCenter 5.0!\n";
        Util::disconnect();
        exit;
}

my $extMgr = Vim::get_view(mo_ref => Vim::get_service_content()->extensionManager);

eval {
	#extension descriptions + Company
	my $customAppExtDesc = Description->new(label => 'Custom Application', summary => 'Custom Application with Appplication + DB Server');
	my $customAppExtCompany = "Primp Industries";

	my $vGhettoExtDesc = Description->new(label => 'vGhetto', summary => 'vGhetto Stuff');
	my $vGhettoExtCompany = "William Lam";

	#Solution Tabs
	my $vGhettoExtTab1 = ExtSolutionManagerInfoTabInfo->new(label => 'vGhetto Health Check', url => 'http://scofield.primp-industries.com');
	my $vGhettoExtTab2 = ExtSolutionManagerInfoTabInfo->new(label => 'vGhetto Blog', url => 'http://williamlam.com');

	my @vGhettoExtTabs;
	push @vGhettoExtTabs, $vGhettoExtTab1;
	push @vGhettoExtTabs, $vGhettoExtTab2;

	my $vGhettoExtSoluInfo = ExtSolutionManagerInfo->new(tab => \@vGhettoExtTabs);
	
	#Solution icons
	my $customAppExtIcon1 = ExtManagedEntityInfo->new(description => 'Application Server', smallIconUrl => 'http://scofield.primp-industries.com/webserver.png', type => 'app');
	my $customAppExtIcon2 = ExtManagedEntityInfo->new(description => 'Database Server', smallIconUrl => 'http://scofield.primp-industries.com/db.png', type => 'db');
	my $vGhettoExtIcon1 = ExtManagedEntityInfo->new(description => 'vGhetto', smallIconUrl => 'http://scofield.primp-industries.com/vg.png', type => 'vg');

	my (@customAppExtIcons,@viewExtIcons,@vGhettoExtIcons,@vmwareMgmtExtIcons);
	push @customAppExtIcons, $customAppExtIcon1;
	push @customAppExtIcons, $customAppExtIcon2;
	push @vGhettoExtIcons, $vGhettoExtIcon1;

	#register extensions
	my $customAppExt = Extension->new(description => $customAppExtDesc, company => $customAppExtCompany, key => 'com.vmware.customApp', lastHeartbeatTime => '1970-01-01T00:00:00Z', version => '5.0', shownInSolutionManager => 'true', managedEntityInfo => \@customAppExtIcons);
	$extMgr->RegisterExtension(extension => $customAppExt);

	my $vGhettoExt = Extension->new(description => $vGhettoExtDesc, company => $vGhettoExtCompany, key => 'com.vmware.vGhetto', lastHeartbeatTime => '1970-01-01T00:00:00Z', version => '5.0', shownInSolutionManager => 'true', solutionManagerInfo => $vGhettoExtSoluInfo, managedEntityInfo => \@vGhettoExtIcons);
	$extMgr->RegisterExtension(extension => $vGhettoExt);
};
if($@) {
	print "Error: " . $@ . "\n";
}

Util::disconnect();
