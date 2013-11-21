#!/usr/bin/perl -w
# Copyright (c) 2009-2011 William Lam All rights reserved.

# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. The name of the author or contributors may not be used to endorse or
#    promote products derived from this software without specific prior
#    written permission.
# 4. Consent from original author prior to redistribution

# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

# William Lam
# http://www.virtuallyghetto.com/

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
	my $vGhettoExtTab2 = ExtSolutionManagerInfoTabInfo->new(label => 'vGhetto Blog', url => 'http://virtuallyghetto.com');

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
