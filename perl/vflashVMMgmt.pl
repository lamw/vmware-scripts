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
#
# William Lam
# http://www.virtuallyghetto.com/

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
