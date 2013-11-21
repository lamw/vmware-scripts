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
# 10/11/2009
# http://communities.vmware.com/docs/DOC-10885
# http://engineering.ucsb.edu/~duonglt/vmware/
##################################################################
use strict;
use warnings;
use Term::ANSIColor;
use VMware::VIRuntime;
use VMware::VILib;

my %opts = (
   showthin => {
      type => "=s",
      help => "Whether or not to display thin provsioned VM(s) only [0|1]",
      required => 0,
      default => 0,
   },
);

$SIG{__DIE__} = sub{Util::disconnect();};

Opts::add_options(%opts);

# validate options, and connect to the server
Opts::parse();
Opts::validate();
Util::connect();

my ($vm_view,$vmname,$showthin,$thin_disk_string,$vm_output_string);

$showthin = Opts::get_option('showthin');

$vm_view = Vim::find_entity_views(view_type => 'VirtualMachine');

foreach( sort {$a->summary->config->name cmp $b->summary->config->name} @$vm_view) {
	if($_->summary->runtime->connectionState->val eq 'connected') {
		if(!$_->config->template) {
			$vmname = $_->summary->config->name;
			my $devices = $_->config->hardware->device;
			my $disk_string;
			my $thin_disk_string;
			my $isThin = 0;
			foreach(@$devices) {
				if($_->isa('VirtualDisk')) {
					my $label = $_->deviceInfo->label;
					my $diskName = $_->backing->fileName;
					my $mode = $_->backing->diskMode;
					my $scsi_adapter = $_->controllerKey;
					$scsi_adapter =~ s/100//;
					my $scsi_target = $_->unitNumber;
					my $format = (($_->backing->thinProvisioned) ? color("green") . "isThinProvsioned" . color("reset") : color("red") . "isNotThinProvisioned" . color("reset"));
					if($_->backing->thinProvisioned) {
						$thin_disk_string .= "\t" . $label . " = " . $diskName . "\n";
						$thin_disk_string .= "\t" . $label . " = " . $format . "\n";
						$thin_disk_string .= "\t" . $label . " = " . $mode . "\n";
						$thin_disk_string .= "\t" . $label . " = " . ref($_->backing) . "\n";
						$thin_disk_string .= "\t" . $label . " = " . "SCSI($scsi_adapter:$scsi_target)\n\n";
					}
					$disk_string .= "\t" . $label . " = " . $diskName . "\n";
					$disk_string .= "\t" . $label . " = " . $format . "\n";
					$disk_string .= "\t" . $label . " = " . $mode . "\n";
					$disk_string .= "\t" . $label . " = " . ref($_->backing) . "\n";
					$disk_string .= "\t" . $label . " = " . "SCSI($scsi_adapter:$scsi_target)\n\n"
				}
			}
			if($showthin eq '1') {
				$vm_output_string .= color("yellow") . $vmname . color("reset") . "\n" . $thin_disk_string . "\n" if($thin_disk_string);
			} else {
				$vm_output_string .= color("yellow") . $vmname . color("reset") . "\n" . $disk_string . "\n" if($disk_string);
			}
		}
	}
}

print $vm_output_string;

Util::disconnect();
