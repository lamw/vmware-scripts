#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://www.williamlam.com/2013/10/exploring-vsphere-flash-read-cache-vfrc.html

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

$SIG{__DIE__} = sub{Util::disconnect()};

my %opts = (
   operation => {
      type => "=s",
      help => "Operation to perform on VM [query|enable|disable]",
      required => 1,
   },
   vmname => {
      type => "=s",
      help => "Name of VM",
      required => 1,
   },
   disk => {
      type => "=s",
      help => "Name of VMDK Disk (e.g. Hard Disk 1)",
      required => 1,
   },
   blocksize => {
      type => "=s",
      help => "Blocksize in KB [4,8,16,32,64,128,256,512,1024",
      required => 0,
      default => 4,
   },
   reservation => {
      type => "=s",
      help => "Reservation in MB",
      required => 0,
      default => 0,
   },
   cachetype => {
      type => "=s",
      help => "Strong will leave cache data in consistent state else it is not guaranteed after crash [strong|weak]",
      required => 0,
      default => "strong"
   },
   cachemode => {
      type => "=s",
      help => "Specifies whether the cache mode is write-back or write-thru [writeback|writethru]",
      required => 0,
      default => "writethru"
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $operation = Opts::get_option('operation');
my $vmname = Opts::get_option('vmname');
my $blocksize = Opts::get_option('blocksize');
my $reservation = Opts::get_option('reservation');
my $cachetype = Opts::get_option('cachetype');
my $cachemode = Opts::get_option('cachemode');
my $disk = Opts::get_option('disk');

my %mode = ('writethru','write_thru','writeback','write_back');

my $vm = Vim::find_entity_view(view_type => 'VirtualMachine', filter => {name => $vmname});

my $devices = $vm->config->hardware->device;
my ($vmdk,$vfrcConfiguration);

foreach my $device (@$devices) {
	if($device->isa("VirtualDisk")) {
		if($device->deviceInfo->label eq $disk) {
			$vmdk = $device;
			last;
		}
	}
}

if($operation eq "query") {
	if(defined($vmdk->vFlashCacheConfigInfo)) {
		my $vflashConfig = $vmdk->vFlashCacheConfigInfo;
		print "\nVM Disk: " . $vmdk->deviceInfo->label . "\n";
		print "vFlash Module: " . $vflashConfig->vFlashModule . "\n";
		print "vFlash Cache Mode: " . $vflashConfig->cacheMode . "\n";
		print "vFlash Cache Consistency Type: " . $vflashConfig->cacheConsistencyType . "\n";
		print "vFlash Blocksize: " . $vflashConfig->blockSizeInKB . " KB\n";
		print "vFlash Reservation: " . $vflashConfig->reservationInMB . " MB\n\n";
	} else {
		print "vSphere Flash Read Cache is not configured on this VM\n\n";
	}
} elsif($operation eq "enable" || $operation eq "disable") {
	if($operation eq "disable") { 
		$reservation = 0;
	} else {
		unless($reservation) {
			print "Error: You need to specify the reservation (MB) using --reservation for amount of vSphere Read Cache to assign to VM\n\n";
			Util::disconnect();
			exit 1;
		}
	}

	$vfrcConfiguration = VirtualDiskVFlashCacheConfigInfo->new(blockSizeInKB => $blocksize, reservationInMB => $reservation, cacheConsistencyType => $cachetype, cacheMode => $mode{$cachemode}, vFlashModule => "vfc");
               
	my $diskSpec = VirtualDisk->new(controllerKey => $vmdk->controllerKey,
        	unitNumber => $vmdk->unitNumber,
	        key => $vmdk->key,
        	backing => $vmdk->backing,
	        deviceInfo => $vmdk->deviceInfo,
        	capacityInKB => $vmdk->capacityInKB,
		vFlashCacheConfigInfo => $vfrcConfiguration,
	);

	my $devspec = VirtualDeviceConfigSpec->new(operation => VirtualDeviceConfigSpecOperation->new('edit'),
        	device => $diskSpec,
	);

	my $vmspec = VirtualMachineConfigSpec->new(deviceChange => [$devspec]);
	eval {
        	print $operation . " vFlash for " . $vm->name . " with blocksize of " . $blocksize . " KB and reservation of " . $reservation . " MB \n";
	        my $task = $vm->ReconfigVM_Task(spec => $vmspec);
        	my $msg = "\tSucessfully reconfigured " . $vm->name . "\n";
 	       &getStatus($task,$msg);
	};
	if($@) {
        	print "ERROR " . $@ . "\n";
	}
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
