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
# 08/11/2009
# http://communities.vmware.com/docs/DOC-10563
# http://www.virtuallyghetto.com/

use strict;
use warnings;
use VMware::VIFPLib;
use VMware::VIRuntime;

Opts::parse();
Opts::validate();
Util::connect();

my $vm_views = Vim::find_entity_views(
                view_type => "VirtualMachine",
);

unless (defined $vm_views){
        die "No VMs found!\n";
}

my ($vmname,$hardware_version,$tools_version,$tools_status) = ('VM Name','vHardware','Tools Version','Tools Status');

format output =
@<<<<<<<<<<<<<<<<<<<<<<<<<@<<<<<<<<<<<<@<<<<<<<<<<<<<<<<<@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$vmname,        $hardware_version,  $tools_version, $tools_status
---------------------------------------------------------------------------------------
.

$~ = 'output';
write;

foreach( sort {$a->config->name cmp $b->config->name} @$vm_views) {
	$vmname = $_->config->name;
	if(defined($_->guest->toolsStatus)) {	
		$tools_status = $_->guest->toolsStatus->val;
		$tools_version = ($_->guest->toolsVersion ? $_->guest->toolsVersion : "N/A");
		$hardware_version = $_->config->version;
	} else {
		$tools_status = "Not defined";
	}
	write;
}

Util::disconnect();
