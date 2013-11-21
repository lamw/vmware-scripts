#!/usr/bin/perl -w
# Copyright (c) 2009-2010 William Lam All rights reserved.

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
# 4. Written Consent from original author prior to redistribution

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
# 08/18/2009
# http://communities.vmware.com/docs/DOC-10555
# http://engineering.ucsb.edu/~duonglt/vmware/

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
	ap => {
	type => "=s",
        help => "[0|1] allowPromiscuous",
	required => 1,
	},
	ft => {
        type => "=s",
        help => "[0|1] forgedTransmits",
        required => 1,
        },
	mc => {
        type => "=s",
        help => "[0|1] macChanges",
        required => 1,
        },
        vswitch_name => {
        type => "=s",
        help => "Name of the vSwitch to create",
	required => 1,
        },
	ports => {
        type => "=s",
        help => "Number of ports on the vSwitch",
	required => 0,
	default => 256,
        },
);

# validate options, and connect to the server
Opts::add_options(%opts);

# validate options, and connect to the server
Opts::parse();
Opts::validate();
Util::connect();

my ($host_view,$ap,$ft,$mc,$vswitch_name,$ports,$task_ref);

$ap = Opts::get_option('ap');
$ft = Opts::get_option('ft');
$mc = Opts::get_option('mc');
$vswitch_name = Opts::get_option('vswitch_name');
$ports = Opts::get_option('ports');

$host_view = Vim::find_entity_view(view_type => 'HostSystem');

unless (defined $host_view){
	die "No ESX(i) host found.\n";	
}

my $networkSystem = Vim::get_view(mo_ref => $host_view->configManager->networkSystem);

eval {
	my $security_policy = HostNetworkSecurityPolicy->new(allowPromiscuous => $ap, forgedTransmits => $ft, macChanges => $mc);
	my $failureCriteria = HostNicFailureCriteria->new(checkBeacon => 1,checkDuplex => 1,checkErrorPercent => 1,checkSpeed => '',fullDuplex => 1,percentage => '5',speed => '14',);
	my $nicorderPolicy = HostNicOrderPolicy->new();
	my $nicTeamPolicy = HostNicTeamingPolicy->new(nicOrder => $nicorderPolicy, notifySwitches => 1, reversePolicy => 0, rollingOrder => 1,policy => 'loadbalance_srcmac',failureCriteria => $failureCriteria);
	my $offloadPolicy = HostNetOffloadCapabilities->new(csumOffload => 0, tcpSegmentation => 0, zeroCopyXmit => 0);
	my $shapePolicy = HostNetworkTrafficShapingPolicy->new(averageBandwidth => 102400,burstSize => 102400,enabled => 0,peakBandwidth => 102400);
	my $vswitch_policy = HostNetworkPolicy->new(security => $security_policy, nicTeaming => $nicTeamPolicy, offloadPolicy => $offloadPolicy, shapingPolicy => $shapePolicy);
	my $vswitch_spec = HostVirtualSwitchSpec->new(numPorts => $ports, policy => $vswitch_policy);

	print "Adding new vSwitch: \"$vswitch_name\" with the following conf: \n\t[allowPromiscuous $ap]\n\t[forgedTransmits $ft]\n\t[macChanges $mc]\n\t[ports $ports]\n\n";
	$task_ref = $networkSystem->AddVirtualSwitch(vswitchName => $vswitch_name, spec => $vswitch_spec);
};
if($@) {
	print "Error: " . $@ . "\n";
}

Util::disconnect();
