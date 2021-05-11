#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://communities.vmware.com/docs/DOC-11932 http://communities.vmware.com/docs/DOC-9852

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;
use Term::ANSIColor;

$SIG{__DIE__} = sub{Util::disconnect();};

Opts::parse();
Opts::validate();
Util::connect();
my $hosttype = &validateConnection('4.0.0','undef','HostAgent');

my $host = Vim::find_entity_view(view_type => 'HostSystem');
my $vms = Vim::find_entity_views(view_type => 'VirtualMachine');

my $storageSys = Vim::get_view (mo_ref => $host->configManager->storageSystem);

my %datastore_mapping = ();
my %vm_mapping = ();

&get_vmfs_mapping($storageSys);
&get_vm_mapping($vms);
&print_mappings();

Util::disconnect();

sub print_mappings {
	foreach my $diskpath (sort { $vm_mapping {$a} cmp $vm_mapping {$b}} keys %vm_mapping) {
		my $vm = $vm_mapping{$diskpath};
		my ($vm_datastore,$vmdk) = split(' ',$diskpath,2);		
		$vm_datastore =~ s/\[//g;
		$vm_datastore =~ s/\]//g;
		print color("yellow") . "VM: " . $vm . "\n" . color("reset");
		print color("green") . "VMDK: " . $diskpath . "\n" . color("reset");
		print color("cyan") . "DEVICE: " . $datastore_mapping{$vm_datastore} . "\n\n" . color("reset");
	}
}

sub get_vm_mapping {
	my ($vms) = @_;

	foreach(@$vms) {
		my $vmname = $_->name;
		my $vmfiles = $_->layoutEx->file;
		foreach(@$vmfiles) {
			if($_->type eq 'diskDescriptor') {
				$vm_mapping{$_->name} = $vmname;
			}
		}
	}
}

sub get_vmfs_mapping {
	my ($ss) = @_;
   	my $fsmount = $ss->fileSystemVolumeInfo->mountInfo;
   	my $luns = $ss->storageDeviceInfo->scsiLun;

   	if ($fsmount) {
      		my $volume = undef;
      		my $extents = undef;
     	 	my $diskName = undef;
      		my $partition = undef;
      		my ($displayName,$deviceName) = ('','');
      		foreach my $fsm (@$fsmount) {
         		$volume = $fsm->volume;
         		if($volume->type eq 'VMFS') {
            			$extents = $volume->extent;
            			foreach my $extent (@$extents) {
               				$diskName = $extent->diskName;
               				foreach my $lun (@$luns) {
                  				if($diskName eq $lun->canonicalName) {
							$deviceName = $lun->deviceName;
                     					$displayName = $lun->displayName;
                     					last;
                  				}
               				}
               				$partition = $extent->partition;
		
					if(!$datastore_mapping{$volume->name}) {
						$datastore_mapping{$volume->name} = "$deviceName:$partition $displayName:$partition";
					}
            			}
         		} else {
				$datastore_mapping{$volume->name} = "NFS";
			}
      		}
   	}
}

sub validateConnection {
        my ($host_version,$host_license,$host_type) = @_;
        my $service_content = Vim::get_service_content();
        my $licMgr = Vim::get_view(mo_ref => $service_content->licenseManager);

        ########################
        # CHECK HOST VERSION
        ########################
        if(!$service_content->about->version ge $host_version) {
                Util::disconnect();
                print color("red") . "This script requires your ESX(i) host to be greater than $host_version\n\n" . color("reset");
                exit 1;
        }

        ########################
        # CHECK HOST LICENSE
        ########################
        my $licenses = $licMgr->licenses;
        foreach(@$licenses) {
                if($_->editionKey eq 'esxBasic' && $host_license eq 'licensed') {
                        Util::disconnect();
                        print color("red") . "This script requires your ESX(i) be licensed, the free version will not allow you to perform any write operations!\n\n" . color("reset");
                        exit 1;
                }
        }

        ########################
        # CHECK HOST TYPE
        ########################
        if($service_content->about->apiType ne $host_type && $host_type ne 'both') {
                Util::disconnect();
                print color("red") . "This script needs to be executed against $host_type\n\n" . color("reset");
                exit 1
        }

        return $service_content->about->apiType;
}
