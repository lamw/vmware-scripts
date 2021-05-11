#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://communities.vmware.com/docs/DOC-11135

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

