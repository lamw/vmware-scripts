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
use Term::ANSIColor;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
	vm => {
		type => "=s",
                help => "Name of virtual machine",
		required => 1,
	},
);

# validate options, and connect to the server
Opts::add_options(%opts);

Opts::parse();
Opts::validate();
Util::connect();

my $vm = Opts::get_option('vm');
my %appStatusColor = ("appStatusGray","white","appStatusGreen","green","appStatusRed","red");
my $productSupport = "both";
my @supportedVersion = qw(4.1.0 5.0.0);

&validateSystem(Vim::get_service_content()->about->version,Vim::get_service_content()->about->productLineId);

my $vm_view = Vim::find_entity_view(view_type => 'VirtualMachine', filter => {'name' => $vm});

unless($vm_view) {
	&print("Unable to locate VM: " . $vm . "\n\n","yellow");
	Util::disconnect();
	exit 1;
}

if($vm_view->guest) {
	if($vm_view->guest->appHeartbeatStatus) {
		&print("App Heartbeat Status is currently: " . $vm_view->guest->appHeartbeatStatus . "\n\n",$appStatusColor{$vm_view->guest->appHeartbeatStatus});
	} else {
		&print("App Heartbeat Status not available\n\n","yellow");
	}
} else {
	&print("VMware Tools may not be installed or is not running\n\n","red");
}

Util::disconnect();

sub validateSystem {
        my ($ver,$product) = @_;

        if(!grep(/$ver/,@supportedVersion)) {
                Util::disconnect();
                &print("Error: This script only supports vSphere \"@supportedVersion\" or greater!\n\n","red");
                exit 1;
        }

	if($product ne $productSupport && $productSupport ne "both") {
		Util::disconnect();
                &print("Error: This script only supports vSphere $productSupport!\n\n","red");
                exit 1;
	}
}

sub print {
	my ($msg,$color) = @_;

	print color($color) . $msg . color("reset");
}

=head1 NAME

getVMAppStatus.pl - Script to retrieve App Heartbeat Status

=head1 Examples

=over 4

=item 

./getVMAppStatus.pl --server [VCENTER_SERVER|ESXi] --username [USERNAME] --vm [VMNAME]

=back



=head1 SUPPORT

vSphere 4.1, 5.0

=head1 AUTHORS

William Lam, http://www.virtuallyghetto.com/

=cut
