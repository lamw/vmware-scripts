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

##################################################################
# Author: William Lam
# 11/02/2009
# http://communities.vmware.com/docs/DOC-11135
# http://engineering.ucsb.edu/~duonglt/vmware/
##################################################################
use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;

# validate options, and connect to the server
Opts::parse();
Opts::validate();
Util::connect();

my $vm_view = Vim::find_entity_views(view_type => 'VirtualMachine');

foreach(@$vm_view) {
	if($_->runtime->connectionState->val eq "connected") {
		if(!$_->summary->config->template) {
			my $rdm_string = "";
	        	my $vm_name = $_->summary->config->name;
        		my $devices =$_->config->hardware->device;
		        foreach(@$devices) {
	        	        if($_->isa("VirtualDisk")) {
					if($_->backing->isa("VirtualDiskRawDiskMappingVer1BackingInfo") || $_->backing->isa("VirtualDiskPartitionedRawDiskVer2BackingInfo")) {
						$rdm_string .= $vm_name . "\n";
						$rdm_string .= "\tDeviceName: " . $_->backing->deviceName . "\n";
						$rdm_string .= "\tFileName: " . $_->backing->fileName . "\n";			
						$rdm_string .= "\tCompatMode: " . $_->backing->compatibilityMode . "\n\n";
					}
                		}
				print $rdm_string;
        		}
		}
	}
}

Util::disconnect();

