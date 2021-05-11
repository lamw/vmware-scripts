#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://communities.vmware.com/docs/DOC-11605

use strict;
use warnings;
use Term::ANSIColor;
use VMware::VILib;
use VMware::VIRuntime;

$SIG{__DIE__} = sub{Util::disconnect();};

my %opts = (
   operation => {
      type => "=s",
      help => "[query|mount|umount]",
      required => 1,
   },
   vmname => {
      type => "=s",
      help => "Name of VM to mount/umount floppy image",
      required => 0,
   },
   filename => {
      type => "=s",
      help => "Name of the floppy image to mount (e.g. myfloppy.flp)",
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

my $vm_view = Vim::find_entity_view(view_type => 'VirtualMachine', filter => {"config.name" => $vmname});

unless($vm_view) {
	Util::disconnect();
	die "Unable to locate VM: \"$vmname\"\n";
}

if($operation eq "query") {
	print "Searching for floppy images on datastores .... this can take a few minutes\n\n";
	&queryFloppys($vm_view);
	print "\n";
} elsif($operation eq "mount") {
	unless($vmname && $filename) {
		Util::disconnect();
		die "For \"mount\" operation, you need the following params defined: vmname & filename!\n";
	}
	&mountFloppy($vm_view,$filename);
} elsif($operation eq "unmount") {
	unless($vmname) {
		Util::disconnect();
                die "For \"unmount\" operation, you need the following params defined: vmname!\n";
	}
	&umountFloppy($vm_view);
} else {
	print color("red") . "Invalid selection!\n" . color("reset");
}

Util::disconnect();

sub umountFloppy {
	my ($vm) = @_;

	my $device= &find_device(vm => $vm,
                                   controller => "Floppy drive 1"
        );

        if($device) {
		my $connectInfo = VirtualDeviceConnectInfo->new(allowGuestControl => 'false', connected => 'false', startConnected => 'false');

                my $floppy = VirtualFloppy->new(controllerKey => $device->controllerKey,
                        unitNumber => $device->unitNumber,
                        key => $device->key,
                        backing => $device->backing,
			connectable => $connectInfo
               );

                my $devspec = VirtualDeviceConfigSpec->new(operation => VirtualDeviceConfigSpecOperation->new('edit'),
                        device => $floppy
                );

                my $vmspec = VirtualMachineConfigSpec->new(deviceChange => [$devspec] );
                eval {
                        print color("yellow") . "Unmounting floppy image: \"" . $device->backing->fileName . "\" from " . $vm->name . " ...\n" . color("reset");
			my $task; eval {
                        $task = $vm->ReconfigVM_Task( spec => $vmspec );
			}; if($@) { print $@ . "\n"; }
                        my $msg = color("green") . "\tSuccessfully unmounted floppy image from VM!\n" . color("reset");
                        &getStatus($task,$msg);
                };
                if($@) {
                        print color("red") . "\nError: " . $@ . "\n" . color("reset");
                }
	} else {
                print color("red") . "\nError: Unable to locate floppy device from VM: \"" . $vm->name . "\"\n" . color("reset");
        }
}

sub mountFloppy {
	my ($vm,$file) = @_;

	my $device= &find_device(vm => $vm,
                                   controller => "Floppy drive 1"
	);

	if($device) {
		my $floppy_backing_info = VirtualFloppyImageBackingInfo->new(fileName => $file);
		my $connectInfo = VirtualDeviceConnectInfo->new(allowGuestControl => 'true', connected => 'true', startConnected => 'true');

	        my $floppy = VirtualFloppy->new(controllerKey => $device->controllerKey,
        		unitNumber => $device->unitNumber,
                	key => $device->key,
	                backing => $floppy_backing_info,
			connectable => $connectInfo
		);

	        my $devspec = VirtualDeviceConfigSpec->new(operation => VirtualDeviceConfigSpecOperation->new('edit'),
        		device => $floppy
		);

		my $vmspec = VirtualMachineConfigSpec->new(deviceChange => [$devspec] );
                eval {
			print color("yellow") . "Mounting floppy image: \"$file\" to " . $vm->name . " ...\n" . color("reset");
                  	my $task = $vm->ReconfigVM_Task( spec => $vmspec );
			my $msg = color("green") . "\tSuccessfully mounted floppy image to VM!\n" . color("reset");
			&getStatus($task,$msg);
                };
		if($@) {
			print color("red") . "\nError: " . $@ . "\n" . color("reset");
		}
	} else {
		print color("red") . "\nError: Unable to locate floppy device from VM: \"" . $vm->name . "\"\n" . color("reset");
	}
}

sub queryFloppys {
	my ($vm) = @_;

	my $host = Vim::get_view(mo_ref => $vm->runtime->host);
	my $datastores = Vim::get_views(mo_ref_array => $host->datastore);
	foreach(@$datastores) {
		my $ds_path = "[" . $_->name . "]";
		my $file_query = FileQueryFlags->new(fileOwner => 0, fileSize => 1,fileType => 1,modification => 0);
        	my $searchSpec = HostDatastoreBrowserSearchSpec->new(details => $file_query, matchPattern => ["*.flp"]);
                my $browser = Vim::get_view(mo_ref => $_->browser);
                my $search_res = $browser->SearchDatastoreSubFolders(datastorePath => $ds_path,searchSpec => $searchSpec);

                if($search_res) {
                	foreach my $result (@$search_res) {
                        	my $folderPath = $result->folderPath;
                                my $files = $result->file;
                                if($files) {
                                	foreach my $file (@$files) {
                                        	my ($filename,$filepath,$filesize);
                                                $filename = $file->path;
                                                $filepath = $folderPath . "/" . $filename;
                                                $filesize = $file->fileSize;
                                                print color("yellow") . &prettyPrintData($filesize,'B') . "\t" . $filepath . "\n" . color("reset");
                                        }
                                }
                        }
                 }
        }
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

#http://www.bryantmcgill.com/Shazam_Perl_Module/Subroutines/utils_convert_bytes_to_optimal_unit.html
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
