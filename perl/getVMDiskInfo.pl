#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://communities.vmware.com/docs/DOC-10885

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
