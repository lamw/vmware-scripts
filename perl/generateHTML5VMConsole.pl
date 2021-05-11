#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://www.williamlam.com/2013/09/how-to-generate-pre-authenticated-html5.html

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
        vm => {
        type => "=s",
        help => "The name of virtual machine",
        required => 1,
        },
        isvSphere55u2 => {
        type => "=s",
        help => "Whether vCenter Server is 5.5 Update 2 for Secure HTML5 Console",
        required => 0,
        default => "false"
        },
);

# validate options, and connect to the server
Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $vmname = Opts::get_option('vm');
my $isvSphere55u2 = Opts::get_option('isvSphere55u2');
my $server = Opts::get_option('server');
my $htmlPort = 7331;
my $secureHtmlPort = 7343;
my $port = 443;
my $vcenter_fqdn;

# retrieve vCenter Server FQDN
my $settingsMgr = Vim::get_view(mo_ref => Vim::get_service_content()->setting);
my $settings = $settingsMgr->setting;

foreach my $setting (@$settings) {
	if($setting->key eq 'VirtualCenter.FQDN') {
		$vcenter_fqdn = $setting->value;
		last;
	}
}

# Retrieve session ticket
my $sessionMgr = Vim::get_view(mo_ref => Vim::get_service_content()->sessionManager);
my $session = $sessionMgr->AcquireCloneTicket();

# VM name + MoRef ID
my $vm = Vim::find_entity_view(view_type => 'VirtualMachine', filter => { name => $vmname });
my $vm_mo_ref_id = $vm->{'mo_ref'}->value;

# vCenter Server SHA1 SSL Thumbprint
my $vcenterSSLThumbprint = `openssl s_client -connect $server:$port < /dev/null 2>/dev/null | openssl x509 -fingerprint -noout -in /dev/stdin | awk -F = '{print \$2}'`;

# VM console URL
if ($isvSphere55u2 eq "true") {
	print "https://" . $server . ":" . $secureHtmlPort . "/console/?vmId=" . $vm_mo_ref_id . "&vmName=" . $vmname . "&host=" . $vcenter_fqdn . "&sessionTicket=" . $session . "&thumbprint=" . $vcenterSSLThumbprint . "\n";
} else {
	print "http://" . $server . ":" . $htmlPort . "/console/?vmId=" . $vm_mo_ref_id . "&vmName=" . $vmname . "&host=" . $vcenter_fqdn . "&sessionTicket=" . $session . "&thumbprint=" . $vcenterSSLThumbprint . "\n";
}
print "Sleeping for 60 seconds and then exiting ...\n";
sleep(60);

Util::disconnect();
