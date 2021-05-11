#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://www.williamlam.com/2011/08/new-application-awareness-api-in.html

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

William Lam, http://www.williamlam.com/

=cut
