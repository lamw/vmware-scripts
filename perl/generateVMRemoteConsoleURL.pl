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
# www.virtuallyghetto.com
#####################################################################

#use strict;
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
