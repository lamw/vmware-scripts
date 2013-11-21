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

# William Lam
# 02/05/2009
# http://communities.vmware.com/docs/DOC-11932
# http://engineering.ucsb.edu/~duonglt/vmware/
# http://communities.vmware.com/docs/DOC-9852
##################################################

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
