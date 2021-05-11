#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://www.williamlam.com/2011/10/how-to-generate-vm-remote-console-url.html

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;
use MIME::Base64;

my ($vc_name,$vmname,$vm_view,$obfuscate,$tail_string,$permission_string);

my %opts = (
        vmname => {
        type => "=s",
        help => "Name of the Virutal Machine",
        required => 1,
        },
        obfuscate => {
        type => "=s",
        help => "obfuscate URL [0|1]",
        required => 0,
        default => 0,
        },
        limit_single_vm_view => {
        type => "=s",
        help => "Limit veiw to a single virtual machine [0|1]",
        required => 0,
        default => 1,
        },
        limit_workspace_view  => {
        type => "=s",
        help => "Limit workspace view to console [0|1]",
        required => 0,
        default => 1,
        },
);

# validate options, and connect to the server
Opts::add_options(%opts);

# validate options, and connect to the server
Opts::parse();
Opts::validate();
Util::connect();

$vmname = Opts::get_option('vmname');
$obfuscate = Opts::get_option('obfuscate');
$vc_name = Opts::get_option('server');

my $remoteURL = "";
my $vcVersion = Vim::get_service_content()->about->version;

$vm_view = Vim::find_entity_view(view_type => 'VirtualMachine', filter => {"name" => $vmname});

unless($vm_view) {
        Util::disconnect();
        die "Unable to locate VM: \"$vmname\"!\n";
}

if($vcVersion eq "5.1.0" || $vcVersion eq "5.5.0") {
	my $vcInstanceUUID =  Vim::get_service_content()->about->instanceUuid;
	my $vmMoRef = $vm_view->{'mo_ref'}->{'value'};
	$remoteURL = "https://$vc_name:9443/vsphere-client/vmrc/vmrc.jsp?vm=urn:vmomi:VirtualMachine:$vmMoRef:$vcInstanceUUID";
} elsif($vcVersion eq "5.0.0") {
	my $vcInstanceUUID =  Vim::get_service_content()->about->instanceUuid;
	my $vmMoRef = $vm_view->{'mo_ref'}->{'value'};
	$remoteURL = "https://$vc_name:9443/vsphere-client/vmrc/vmrc.jsp?vm=$vcInstanceUUID:VirtualMachine:$vmMoRef";
} else {
	if($obfuscate eq "") {
		Util::disconnect();
		print "Please specify whether or not to obfuscate URL! with --obfuscate parameter!\n";
		exit 1;
	}

	if(!Opts::get_option('limit_single_vm_view')) {
        	$permission_string = "&inventory=expanded";
	} else {
        	 $permission_string = "&inventory=none";
	}

	if(!Opts::get_option('limit_workspace_view')) {
        	$permission_string .= "&tabs=show_";
	} else {
	        $permission_string .= "&tabs=hide_";
	}

	my $vm_mo_ref_id = $vm_view->{'mo_ref'}->value;
	if($obfuscate eq "1") {
        	$tail_string = "http://localhost:80/sdk&mo=VirtualMachine|${vm_mo_ref_id}${permission_string}";
	        $tail_string = "?view=" . encode_base64($tail_string);
	} else {
        	$tail_string = "?wsUrl=http://localhost:80/sdk&mo=VirtualMachine|${vm_mo_ref_id}${permission_string}";
	}

	$remoteURL = "https://$vc_name/ui/" . $tail_string;
}

print "Here is the Remote Console URL for " . $vm_view->name . "\n" . $remoteURL . "\n";

Util::disconnect();
