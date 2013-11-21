#!/usr/bin/perl -w
# Copyright (c) 2009-2013 William Lam All rights reserved.

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
);

# validate options, and connect to the server
Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $vmname = Opts::get_option('vm');
my $server = Opts::get_option('server');
my $htmlPort = 7331;
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
print "http://" . $server . ":" . $htmlPort . "/console/?vmId=" . $vm_mo_ref_id . "&vmName=" . $vmname . "&host=" . $vcenter_fqdn . "&sessionTicket=" . $session . "&thumbprint=" . $vcenterSSLThumbprint . "\n";
print "Sleeping for 60 seconds and then exiting ...\n";
sleep(60);

Util::disconnect();
