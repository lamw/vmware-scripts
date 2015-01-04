#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://communities.vmware.com/docs/DOC-10974

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

$SIG{__DIE__} = sub{Util::disconnect();};

my %opts = (
   operation => {
      type => "=s",
      help => "[query|add|delete]",
      required => 1,
   },
   vmname => {
      type => "=s",
      help => "Name of VM to add/update custom field",
      required => 1,
   },
   device => {
      type => "=s",
      help => "Name of the device to add RDM (user query operation if you don't know)",
      required => 0,
   },
   filename => {
      type => "=s",
      help => "Name of the RDM",
      required => 0,
   },
   compatmode => {
      type => "=s",
      help => "Compatiablity mode of the RDM [physical|virtual]",
      required => 0,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $operation = Opts::get_option('operation');
my $vmname = Opts::get_option('vmname');
my $device = Opts::get_option('device');
my $filename = Opts::get_option('filename');
my $compat_mode = Opts::get_option('compatmode');

my $diskmode = "persistent";
my ($vm_view);

$vm_view = Vim::find_entity_view(view_type => 'VirtualMachine', filter => {"config.name" => $vmname});

unless($vm_view) {
	Util::disconnect();
	die "Unable to locate VM: \"$vmname\"\n";
}

if($operation eq "query") {
	&queryRDMs($vm_view);
} elsif($operation eq "add") {
	unless($device && $filename && $compat_mode) {
		Util::disconnect();
		die "For \"add\" operation, you need the following parmas defined: device, filename and compatmode!\n";
	}
	&addRDM($vm_view,$device,$filename,$compat_mode,$diskmode);
} elsif($operation eq "destroy") {
	unless($filename) {
		Util::disconnect();
                die "For \"destroy\" operation, you need the following parmas defined: filename!\n";
	}
	&destroyRDM($vm_view,$filename);
} else {
	print "Invalid selection!\n";
}

Util::disconnect();

sub destroyRDM {
	my ($vm,$file) = @_;

   	my ($disk,$config_spec_operation, $config_file_operation);
   	$config_spec_operation = VirtualDeviceConfigSpecOperation->new('remove');
   	$config_file_operation = VirtualDeviceConfigSpecFileOperation->new('destroy');

	$disk = &find_disk(vm => $vm,
		fileName => $file			
        );

   	if($disk) {
     		my $devspec = VirtualDeviceConfigSpec->new(operation => $config_spec_operation,
                	device => $disk,
                        fileOperation => $config_file_operation
		);

		my $vmspec = VirtualMachineConfigSpec->new(deviceChange => [$devspec] );
        	eval {
                	print "Destroying RDM: \"" . $file . "\" to " . $vm->name . " ...\n";
                	my $task = $vm->ReconfigVM_Task( spec => $vmspec );
                	my $msg = "\tSuccessfully destroyed RDM to VM!\n";
                	&getStatus($task,$msg);
        	};
        	if($@) {
                	print "Error: " . $@ . "\n";
        	}
   	} else {
                print "Error: Unable to destroy RDM to VM: \"" . $vm->name . "\"\n";
        }
}

sub addRDM {
	my ($vm,$dev,$file,$compatmode,$dmode) = @_;
	my $found = 0;

	my $controller = &find_device(vm => $vm,
                                   controller => "SCSI controller 0"
	);

      	my $controllerKey = $controller->key;
      	my $unitNumber = $#{$controller->device} + 1;

	my $host = Vim::get_view(mo_ref => $vm->runtime->host);
        my $luns = $host->config->storageDevice->scsiLun;

	my ($rdmMode,$deviceName,$lunId,$size);
        if($compatmode eq "physical") { $rdmMode = "physicalMode"; } 
	else { $rdmMode = "virtualMode"; }

	my $dsSys = Vim::get_view(mo_ref => $host->configManager->datastoreSystem);
        eval {
                my $disks = $dsSys->QueryAvailableDisksForVmfs();
                foreach(@$disks) {
                	if($_->devicePath eq $dev) {
				$found = 1;

				$deviceName = $_->deviceName;
				$lunId = $_->uuid;
				$size = (($_->capacity->blockSize * $_->capacity->block)/1024);
			}
                }
        };
	if($@) { print "Error: " . $@ . "\n"; }

	if($found eq 1) {
		my $disk_backing_info = VirtualDiskRawDiskMappingVer1BackingInfo->new(compatibilityMode => $rdmMode,
			deviceName => $deviceName,
	                lunUuid => $lunId,
        	        fileName => $file,
			diskMode => $dmode
        	);

	        my $disk = VirtualDisk->new(controllerKey => $controllerKey,
        		unitNumber => $unitNumber,
                	key => -1,
	                backing => $disk_backing_info,
        	        capacityInKB => $size
		);

	        my $devspec = VirtualDeviceConfigSpec->new(operation => VirtualDeviceConfigSpecOperation->new('add'),
        		device => $disk,
                	fileOperation => VirtualDeviceConfigSpecFileOperation->new('create')
		);

		my $vmspec = VirtualMachineConfigSpec->new(deviceChange => [$devspec] );
                eval {
			print "Creating and adding \"$rdmMode\" RDM: \"" . $file . "\" to " . $vm->name . " ...\n";
                  	my $task = $vm->ReconfigVM_Task( spec => $vmspec );
			my $msg = "\tSuccessfully added RDM to VM!\n";
			&getStatus($task,$msg);
                };
		if($@) {
			print "Error: " . $@ . "\n";
		}

	} else {
		print "Error: Unable to create and add RDM to VM: \"" . $vm->name . "\"\n";
	}
}

sub queryRDMs {
	my ($vm) = @_;

	my $host = Vim::get_view(mo_ref => $vm->runtime->host);
	my $luns = $host->config->storageDevice->scsiLun;
	
	my $dsSys = Vim::get_view(mo_ref => $host->configManager->datastoreSystem);
	eval {
		my $disks = $dsSys->QueryAvailableDisksForVmfs();
		foreach(@$disks) {
			my $lunCap = (($_->capacity->blockSize * $_->capacity->block)/1024);
			print "Device Name: " . $_->devicePath . "\n";
			print "Capacity: " . &prettyPrintData($lunCap,'K') . "\n\n";
		}
	};	
	if($@) { print "Error: " . $@ . "\n"; }
}

sub find_device {
   my %args = @_;
   my $vm = $args{vm};
   my $name = $args{controller};

   my $devices = $vm->config->hardware->device;
   foreach my $device (@$devices) {
      return $device if ($device->deviceInfo->label eq $name);
   }
   return undef;
}

sub find_disk {
   my %args = @_;
   my $vm = $args{vm};
   my $name = $args{fileName};

   my $devices = $vm->config->hardware->device;
   foreach my $device (@$devices) {
	if($device->isa('VirtualDisk')) {
		if($device->backing->isa('VirtualDiskRawDiskMappingVer1BackingInfo')) {
			my ($vm_ds,$vmdk_path) = split(' ',$device->backing->fileName,2);
			my ($vm_dir,$vm_vmdk) = split('/',$vmdk_path,2);
      			return $device if ($vm_vmdk eq $name);
		}
	}
   }
   return undef;
}

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

sub prettyPrintData{
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
	elsif($type eq 'K') {
		$size = sprintf("%.2f", ($bytes/1024)) . ' MB' if ($bytes >= 1024 && $bytes < 1048576);
                $size = sprintf("%.2f", ($bytes/1048576)) . ' GB' if ($bytes >= 1048576 && $bytes < 1073741824);
                $size = sprintf("%.2f", ($bytes/1073741824)) . ' TB' if ($bytes >= 1073741824 && $bytes < 1099511627776);
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

        return $size;
}
