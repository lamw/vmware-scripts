#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://www.virtuallyghetto.com/2013/11/exploring-vsphere-flash-read-cache-vfrc.html

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

$SIG{__DIE__} = sub{Util::disconnect()};

my %opts = (
   operation => {
      type => "=s",
      help => "Operation to perform on ESXi host [query|listssd|add|format|extend|destroy]",
      required => 1,
   },
   vihost => {
      type => "=s",
      help => "Name of ESXi host when connecting to vCenter Server",
      required => 0,
   },
   disk => {
      type => "=s",
      help => "Comma seperated list of disk paths (e.g. /vmfs/devices/disks/naa...,/vmfs/devices/disks/naa...)",
      required => 0,
   },
   vffs => {
      type => "=s",
      help => "Name of VFFS volume",
      required => 0,
   },
   vffs_uuid => {
      type => "=s",
      help => "VFFS uuid",
      required => 0,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $operation = Opts::get_option('operation');
my $vihost = Opts::get_option('vihost');
my $disk = Opts::get_option('disk');
my $vffs = Opts::get_option('vffs');
my $vffs_uuid = Opts::get_option('vffs_uuid');
my $host;

if($vihost) {
	$host = Vim::find_entity_view(view_type => 'HostSystem', filter => {name => $vihost});
} else {
	$host = Vim::find_entity_view(view_type => 'HostSystem');
}

my $storageSys = Vim::get_view(mo_ref => $host->configManager->storageSystem);
my $vflashmgr = Vim::get_view(mo_ref => $host->configManager->vFlashManager);

if($operation eq "query") {
	if(defined($vflashmgr->vFlashConfigInfo->vFlashResourceConfigInfo)) {
		my $vflashVolume = $vflashmgr->vFlashConfigInfo->vFlashResourceConfigInfo;
		print "\nvFlash Resource Name: " . $vflashVolume->vffs->name . "\n";
		print "vFlash Resource Capacity: " . &prettyPrint($vflashVolume->capacity,'B') . "\n";
		print "vFlash Resource UUID: " . $vflashVolume->vffs->uuid . "\n";
		print "vFlash Resource Version: " . $vflashVolume->vffs->version . "\n"; 
		print "vFlash Resource SSD(s): \n";
		my $ssdDisks = $vflashVolume->vffs->extent;
		foreach my $ssdDisk (@$ssdDisks) {
			print "\t" . $ssdDisk->diskName . "\n";
		}
		print "\n";
	} else {
		print "vSphere Flash Read Cache is not configured on host\n";
		Util::disconnect();
		exit 1;
	}
} elsif($operation eq "listssd") {
	my $ssdDisks;
	eval {
		$ssdDisks = $storageSys->QueryAvailableSsds();
		foreach my $ssdDisk (@$ssdDisks) {
			print "\nDevice Path: " . $ssdDisk->devicePath . "\n";
			print "Device Model: " . $ssdDisk->model . "\n";
			print "Device Capacity: " .  &prettyPrint(($ssdDisk->capacity->block * $ssdDisk->capacity->blockSize),'B') . "\n";
		}
		print "\n";
	};
	if($@) {
		print "ERROR: " . $@ . "\n";
	}
} elsif($operation eq "add") {
	unless($disk) {
		print "\n\"add\" operation requires --disk parameter to be specified\n\n";
		Util::disconnect();
		exit 1;
	}
	eval {
		my @vflash_disks =  split(',',$disk);
		my $msg = "\tSucessfully reconfigured\n";
		print "\nAdding the following disks: \n\n" . join("\t\n",@vflash_disks) . "\n\nas a Virtual Flash Resource ...\n";
		my $task = $vflashmgr->ConfigureVFlashResourceEx_Task(devicePath => \@vflash_disks);
		&getStatus($task,$msg);
	};
        if($@) {
                print "ERROR: " . $@ . "\n";
        }
} elsif($operation eq "format") {
        unless($vffs && $disk) {
                print "\n\"format\" operation requires both --vffs and --disk parameter to be specified\n\n";
                Util::disconnect();
                exit 1;
        }

	print "Creating and formatting VFFS called " . $vffs . " and adding disk " . $disk . "...\n";
	my $spec = HostVffsSpec->new(devicePath => $disk, majorVersion => '1', volumeName => $vffs);
	my $vffsVolume = $storageSys->FormatVffs(createSpec => $spec);
	if(defined($vffsVolume->uuid)) {
		print "VFFS Resource UUID: " . $vffsVolume->uuid . "\n";
		eval {
			my $spec = HostVFlashManagerVFlashResourceConfigSpec->new(vffsUuid => $vffsVolume->uuid);
			$vflashmgr->HostConfigureVFlashResource(spec => $spec);
		};
		if($@) {
			 print "ERROR: " . $@ . "\n";
		}
	}
} elsif($operation eq "extend") {
	unless($vffs_uuid && $disk) {
		print "\n\"extend\" operation requires both --vffs_uuid and --disk parameter to be specified\n\n";
		Util::disconnect();
		exit 1;
	}
	
	print "Extending VFFS " . $vffs_uuid . " with disk " . $disk . "...\n";
	my $vffsPath = "/vmfs/volumes/" . $vffs_uuid;
	$storageSys->ExtendVffs(vffsPath => $vffsPath, devicePath => $disk);
} elsif($operation eq "destroy") {
	print "Destroying VFFS ...\n";
	$vflashmgr->HostRemoveVFlashResource();
} else {
	print "Invalid Selection!\n";
	exit 1;
}


Util::disconnect();

#### HELPER #####

sub getStatus {
        my ($taskRef,$message) = @_;

        my $task_view = Vim::get_view(mo_ref => $taskRef);
        my $taskinfo = $task_view->info->state->val;
        my $continue = 1;
        while ($continue) {
                my $info = $task_view->info;
                if ($info->state->val eq 'success') {
                        print $message,"\n";
                        return $info->result;
                        $continue = 0;
                } elsif ($info->state->val eq 'error') {
                        my $soap_fault = SoapFault->new;
                        $soap_fault->name($info->error->fault);
                        $soap_fault->detail($info->error->fault);
                        $soap_fault->fault_string($info->error->localizedMessage);
                        die "$soap_fault\n";
                }
                sleep 5;
                $task_view->ViewBase::update_view_data();
        }
}

#http://www.bryantmcgill.com/Shazam_Perl_Module/Subroutines/utils_convert_bytes_to_optimal_unit.html
sub prettyPrint{
        my($bytes,$type) = @_;

        return '' if ($bytes eq '' || $type eq '');
        return 0 if ($bytes <= 0);

        my($size);

        if($type eq 'B') {
                $size = $bytes . ' Bytes' if ($bytes < 1024);
                $size = sprintf("%.2f", ($bytes/1024)) . ' KB' if ($bytes >= 1024 && $bytes < 1048576);
                $size = sprintf("%.2f", ($bytes/1048576)) . ' MB' if ($bytes >= 1048576 && $bytes < 1073741824);
                $size = sprintf("%.2f", ($bytes/1073741824)) . ' GB' if ($bytes >= 1073741824 && $bytes < 1099511627776);
                $size = sprintf("%.2f", ($bytes/1099511627776)) . ' TB' if ($bytes >= 1099511627776);
        }
        elsif($type eq 'M') {
                $bytes = $bytes * (1048576);
                $size = sprintf("%.2f", ($bytes/1048576)) . ' MB' if ($bytes >= 1048576 && $bytes < 1073741824);
                $size = sprintf("%.2f", ($bytes/1073741824)) . ' GB' if ($bytes >= 1073741824 && $bytes < 1099511627776);
                $size = sprintf("%.2f", ($bytes/1099511627776)) . ' TB' if ($bytes >= 1099511627776);
        }

        elsif($type eq 'G') {
                $bytes = $bytes * (1073741824);
                $size = sprintf("%.2f", ($bytes/1073741824)) . ' GB' if ($bytes >= 1073741824 && $bytes < 1099511627776);
                $size = sprintf("%.2f", ($bytes/1099511627776)) . ' TB' if ($bytes >= 1099511627776);
        }
        elsif($type eq 'MHZ') {
                $size = sprintf("%.2f", ($bytes/1e-06)) . ' MHz' if ($bytes >= 1e-06 && $bytes < 0.001);
                $size = sprintf("%.2f", ($bytes*0.001)) . ' GHz' if ($bytes >= 0.001);
        }

        return $size;
}
