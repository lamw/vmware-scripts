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
# 01/31/2010
# http://engineering.ucsb.edu/~duonglt/vmware
# http://communities.vmware.com/docs/DOC-11969
# http://communities.vmware.com/docs/DOC-9852

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;
use VMware::VIExt;
use Term::ANSIColor;
use Data::Serializer;

# define custom options for vm and target host
my %opts = (
   'operation' => {
      type => "=s",
      help => "Operation to perform on host [export|import|dump]",
      required => 1,
   },
   'profile_name' => {
      type => "=s",
      help => "Name of the profile",
      required => 1,
   },
   'profile_description' => {
      type => "=s",
      help => "Description of profile",
      required => 0,
   },
);

# read and validate command-line parameters 
Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();
my $hosttype = &validateConnection('4.0.0','licensed','HostAgent');

my ($operation,$profile,$description);
my %xmloutput;

$operation = Opts::get_option("operation");
$profile = Opts::get_option("profile_name");
$description = Opts::get_option("profile_description");

my $host_view = Vim::find_entity_view(view_type => 'HostSystem');

my $md5ext = ".md5sum";
my $dumpext = ".dump";

#create data serializer object
#secret + cipher will not work due to missing modules
my $obj = Data::Serializer->new(
                         serializer => 'Data::Dumper',
                         digester   => 'SHA-512',
                         cipher     => 'Blowfish',
                         secret     => undef,
                         portable   => '1',
                         compress   => '1',
                         serializer_token => '1',
                         options  => {},
);


if($operation eq 'export') {
	print color("cyan") . "Starting ghetto Export of " . $host_view->name . " configurations ...\n" . color("reset");

	# METADATA
	my $metaConfigs = &getMetaData($host_view);

	# DATASTORE
	my $datastoreConfigs = &getDatastoreSystemConfig($host_view);

	# STORAGE
	my $storageConfigs = &getStorageSystemConfig($host_view);

	# NETWORK vSWITCH
	my $vSwitchConfigs = &getNetworkSystemvSwitchConfig($host_view);

	# NETWORK PORTGROUP
	my $portgroupConfigs = getNetworkSystemPortgroupConfig($host_view);

	# LICENSE
	my $licenseConfigs = &getLicenseSystemConfig($host_view);

	# NTP
	my $ntpConfigs = &getDateTimeSystemConfig($host_view);

	# vNIC
	my $vNicConfigs = &getVirtualNicSystemConfig($host_view);

	# SERVICES
	my $serviceConfigs = &getServiceSystemConfig($host_view);

	# SNMP
	my $snmpConfigs = &getSNMPSystemConfig($host_view);

	# HOST ADV OPTIONS
	my $advOptConfigs = &getAdvancedOptionSystemConfig($host_view);

	my $serialized;
	eval {
		$serialized = $obj->serialize(
			{
				metainfo => $metaConfigs,
				datastore => $datastoreConfigs,
				storage => $storageConfigs,
				vswitch => $vSwitchConfigs,
				portgroup => $portgroupConfigs,
				license => $licenseConfigs,
				ntp => $ntpConfigs,
				vnic => $vNicConfigs,
				service => $serviceConfigs,
				snmp => $snmpConfigs,
				advopt => $advOptConfigs
			}
		);
		$obj->store($serialized,$profile);
	};
	if($@) {
		print color("red") . "\tError: Unable to serialize and/or store configurations\n\n" . color("reset");
		&stopScript();
	} else {
		print color("magenta") . "\tExport completed and saved to \"$profile\"\n\n" . color("reset"); 
	}

	&generatedmd5sum($profile);
}elsif($operation eq 'import') {
	my ($configfile,$deserialized);

	# CHECK MAINT MODE
	&verifyMaintenanceMode($host_view,'on');	

	# BACKUP ORIGINAL HOST
        &backupHost($host_view);

	# VERIFY MD5SUM
        &verifymd5sum($profile);

	eval {
		$configfile = $obj->retrieve($profile);
		$deserialized = $obj->deserialize($configfile);
	};
	if($@) {
		print color("red") . "\tError: Unable to read and/or deserialize configuration file from \"$profile\"\n\n" . color("reset");
		&stopScript();
	}

	my %profileConfig = %$deserialized;

	# PARSE METADATA
	&parseMetaData($profileConfig{'metainfo'},$host_view);

	# NETWORK vSWITCH
	&configureNetworkvSwitch($profileConfig{'vswitch'},$host_view);

	# NETWORK PORTGROUP
	&configureNetworkPortgroup($profileConfig{'portgroup'},$host_view);

	# vNIC
	&configureVirtualNic($profileConfig{'vnic'},$host_view);

	# DATASTORE
      	&configureDatastore($profileConfig{'datastore'},$host_view);

	# STORAGE 
	&configureStorage($profileConfig{'storage'},$host_view);

	# NTP
	&configureDateTime($profileConfig{'ntp'},$host_view);

	# SERVICES
	&configureService($profileConfig{'service'},$host_view);

	# SNMP
	&configureSNMP($profileConfig{'snmp'},$host_view);

	# HOST ADV OPTIONS
	&configureAdvOpt($profileConfig{'advopt'},$host_view);

	# LICSENSE
      	&configureLicense($profileConfig{'license'},$host_view);

	print color("magenta") . "\nConfiguration changes all complete!\n" . color("reset");

	&rebootHost($host_view);
}elsif($operation eq 'dump') {
	my ($configfile,$deserialized);

	$Data::Dumper::Indent = 1;
	
	# VERIFY MD5SUM
        &verifymd5sum($profile);

	eval {
                $configfile = $obj->retrieve($profile);
                $deserialized = $obj->deserialize($configfile);
        };
        if($@) {
                print color("red") . "\tError: Unable to read and/or deserialize configuration file from \"$profile\"\n\n" . color("reset");
                &stopScript();
        }

	my $profiledump = $profile . $dumpext;
	print color("cyan") . "\nDumping current ghettoHostProfile: \"$profile\" to \"$profiledump\" ...\n" . color("reset");
	eval {
		open(GHETTOPROFILE, ">$profiledump");
		print GHETTOPROFILE Dumper($deserialized);
		close(GHETTOPROFILE);
	};
	if($@) {
		print color("red") . "\tError: Failed to dump ghettoHostProfile: \"$profile\"!\n" . color("reset");
	} else {
		print color("green") . "\t\tSuccessfully completed!\n" . color("reset");		
	}
}else {
	print color("red") . "Invalid selection!\n" . color("reset");
}

Util::disconnect();

########################
# HELPER FUNCTIONS
########################

sub configureStorage {
	my ($profiledata,$host) = @_;

	if($profiledata) {
		my $storageInfo = $profiledata;

		my $storageSys = &getStorageSystem($host);
		my %existingiSCSIHBA = ();
		my %existingmpath = ();
		my $iSCSIEnabled = 0;

		print color("green") . "\tApplying Storage configurations ...\n" . color("reset");
		foreach(@$storageInfo) {
			print color("green") . "\t\tEnabling software iSCSI ...\n" . color("reset");
			if($_->softwareInternetScsiEnabled) {
				eval {
					$storageSys->UpdateSoftwareInternetScsiEnabled(enabled => 1);
					$iSCSIEnabled = 1;
					$storageSys->RefreshStorageSystem();
				};
				if($@) {
					print color("red") . "\tUnable to enable software iSCSI! - $@\n" . color("reset");
					&stopScript();
				}
			}
			my $profileHBAs = $_->hostBusAdapter;
			foreach(@$profileHBAs) {
				if($_->isa('HostInternetScsiHba')) {
					if(!$existingiSCSIHBA{$_->device}) {
						$existingiSCSIHBA{$_->device} = $_;
					}
				}
			}
			my $mpathluns = $_->multipathInfo->lun;
			foreach(@$mpathluns) {
				$existingmpath{$_->id} = $_;
			}
		}

		$storageSys->ViewBase::update_view_data();
	
		#configure iSCSI	
		if($iSCSIEnabled) {
			print color("green") . "\t\tConfiguring iSCSI targets ...\n" . color("reset");
                	my $hbas = $storageSys->storageDeviceInfo->hostBusAdapter;
                        foreach(@$hbas) {
                        	my $device = $_->device;
                                if($_->isa('HostInternetScsiHba') && $existingiSCSIHBA{$device}) {
                                	eval {
						my $sendTargets = $existingiSCSIHBA{$device}->configuredSendTarget;
						my @tmp = ();
						foreach(@$sendTargets) {
							my $target = HostInternetScsiHbaSendTarget->new(address => $_->address, port => $_->port);
							push @tmp,$target;
						}
						my $sendTargetArr = \@tmp;
                                        	$storageSys->AddInternetScsiSendTargets(iScsiHbaDevice => $device, targets => $sendTargetArr);
						$storageSys->RescanHba(hbaDevice => $device);
                                        };
                                        if($@) {
                                        	print color("red") . "\tUnable to configure iSCSI targets for: \"  - $@\n" . color("reset");
						&stopScript();
	                                }
				}
                         }
                }

		#configure mpath
		my $luns = $storageSys->storageDeviceInfo->multipathInfo->lun;
		print color("green") . "\t\tConfiguring multipath configurations ...\n" . color("reset");
		foreach(@$luns) {
			if($existingmpath{$_->id}) {
				my $profileLun = $existingmpath{$_->id};
				$storageSys->SetMultipathLunPolicy(lunId => $_->id, policy => $profileLun->policy);
			}
		}
		$storageSys->RefreshStorageSystem();
		print color("green") . "\t\tSuccessfully completed!\n" . color("reset");
	} else {
		print color("yellow") . "No Storage configurations found!\n" . color("reset");
	}
}

sub configureDatastore {
        my ($profiledata,$host) = @_;

        if($profiledata) {
		my $datastores = $profiledata;

		my $datastoreSys = &getDatastoreSystem($host);
		my $storageSys = getStorageSystem($host);
		
		my $currentDatastores = Vim::get_views(mo_ref_array => $datastoreSys->datastore);
		my %existingDatastores;
		foreach(@$currentDatastores) {
			if(!$existingDatastores{$_->summary->name} && $_->summary->type eq 'NFS') {
				$existingDatastores{$_->summary->name} = "yes";
			}	
		}
		print color("green") . "\tApplying NAS and/or Local Datastore configurations ...\n" . color("reset");
		foreach(@$datastores) {
			my %dsHash = %$_;
			if(!$existingDatastores{$dsHash{'name'}} && $dsHash{'nas'}) {
				eval {
					my $nasVolumeInfo = $dsHash{'nas'};
					my $nasSpec = HostNasVolumeSpec->new(remoteHost => $nasVolumeInfo->remoteHost, remotePath => $nasVolumeInfo->remotePath, type => $nasVolumeInfo->type, localPath => $nasVolumeInfo->name, accessMode => 'readWrite');
					$datastoreSys->CreateNasDatastore(spec => $nasSpec);
				};
				if($@) {
                                	print color("red") . "\tUnable to add NAS Datastore: \"".$dsHash{'name'}."\"! - $@\n" . color("reset");
					&stopScript();
                                }
			}
		}
		foreach(@$currentDatastores) {
			if($_->summary->type ne 'NFS') {
				print color("white") . "\tLocated datastore: \"".$_->summary->name."\" which requires additional input\n\n" . color("reset");
				eval {
					my $rename_ds = &promptUser("Would you like to rename this datastore? [yes|no]");
                                        if($rename_ds =~ m/yes/) {
                                        	my $newname;
                                                my $notConfirm = 1;
                                                while($notConfirm) {
                                                	$newname = &promptUser("Enter new datastore name");
                                                        my $verify = &promptUser("Confirm new datastorename \"$newname\"? [yes|no]");
                                                        if($verify =~ m/yes/) {
                                                        	$notConfirm = 0;
                                                        }
                                                }
						my $task = $_->Rename_Task(newName => $newname);
						&waitOnTask($task);
					}
				};
				if($@) {
					print color("red") . "\tUnable to rename datastore: \"".$_->summary->name."\"! - $@\n" . color("reset");
					&stopScript();
				}
			}
		}
		print color("green") . "\t\tSuccessfully completed!\n" . color("reset");
        } else {
                print color("yellow") . "No NAS or Local Datastore configurations found!\n" . color("reset");
        }
}

sub configureVirtualNic {
	my ($profiledata,$host) = @_;

	if($profiledata) {
		my $vNICs = $profiledata;

		my $vNICSys = &getVirtualNicSystem($host);
		my $networkSys = &getNetworkSystem($host);

		my $currentvNICs = $vNICSys->info->netConfig;		
		my %existingvNICs;
		foreach(@$currentvNICs) {
			my $hostNics = $_->candidateVnic;
			foreach(@$hostNics) {
				if(!$existingvNICs{$_->portgroup}) {
					$existingvNICs{$_->portgroup} = "yes";
				}
			}
		}
		print color("green") . "\tApplying Virtual NIC configurations ...\n" . color("reset");
		#create vMKernel interfaces
		foreach my $vNIC (@$vNICs) {
			my $candidatevNICs = $vNIC->candidateVnic;
			foreach(@$candidatevNICs) {
				my $vNicPgName = $_->portgroup;
				my $vNicSpec = $_->spec;
				if(!$existingvNICs{$vNicPgName}) {
					my ($hostvNicSpec,$hostIpConfig);
					eval {
						print color("white") . "\tCreating vNIC on portgroup: \"$vNicPgName\" requires additional input\n\n" . color("reset");
						my $network_method = &promptUser("Do you want to use DHCP or STATIC IP Configuration? [dhcp|static]");
						if($network_method =~ m/static/) {
							my ($ip,$netmask);
							my $notConfirm = 1;
							while($notConfirm) {
								$ip = &promptUser("Enter IP Addresss [a.b.c.d]");
								$netmask = &promptUser("Enter Netmask [a.b.c.d]");
								my $verify = &promptUser("Confirm IP Address: $ip Netmask: $netmask? [yes|no]");
								if($verify =~ m/yes/) {
									$notConfirm = 0;
								}
							}				
			
							$hostIpConfig = HostIpConfig->new(dhcp => 0, ipAddress => $ip, subnetMask => $netmask);
							$hostvNicSpec = HostVirtualNicSpec->new(ip => $hostIpConfig, mtu => $vNicSpec->mtu, portgroup => $vNicSpec->portgroup, tsoEnabled => $vNicSpec->tsoEnabled);
							$networkSys->AddVirtualNic(portgroup => $vNicPgName, nic => $hostvNicSpec);
						} else {
							$hostIpConfig = HostIpConfig->new(dhcp => 1);
							$hostvNicSpec = HostVirtualNicSpec->new(ip => $hostIpConfig, mtu => $vNicSpec->mtu, portgroup => $vNicSpec->portgroup, tsoEnabled => $vNicSpec->tsoEnabled);
							$networkSys->AddVirtualNic(portgroup => $vNicPgName, nic => $hostvNicSpec);
						}
					};
					if($@) {
                                        	print color("red") . "\tUnable to add Virtual NIC configurations for vNIC: \"".$_->device."\"! - $@\n" . color("reset");
						&stopScript();
                                	}
					$existingvNICs{$vNicPgName} = "yes";
				}
			}
		}

		#update vNIC types
		# assumption is we'll only enable and not disable (FT,MGMT,VMOTION)
		my %vNicHash = ();
		foreach my $vNIC(@$vNICs) {
			my $selectvNICs = $vNIC->selectedVnic;
			foreach(@$selectvNICs) {
				$vNicHash{$_} = "yes";
			}
			my $canidatevNIcs = $vNIC->candidateVnic;	
			foreach(@$canidatevNIcs) {
				if($vNicHash{$_->key}) {	
					my ($type,$dev) = split('.key-vim.host.VirtualNic-',$_->key,2);
					eval {
						$vNICSys->SelectVnicForNicType(nicType => $type, device => $_->device);						
					};
					if($@) {
						print color("red") . "\tUnable to update Virtual NIC for \"$type\" on: \"".$_->device."\"! - $@\n" . color("reset");
						&stopScript();
					}
				}
			}
		}
		print color("green") . "\t\tSuccessfully completed!\n" . color("reset");
	} else {
		 print color("yellow") . "No Virtual NIC configurations found!\n" . color("reset");
	}
}

sub configureNetworkvSwitch {
	my ($profiledata,$host) = @_;

	if($profiledata) {
		my $vSwitches = $profiledata;

		my $networkSys = &getNetworkSystem($host);
		my $currentvSwitches = $networkSys->networkConfig->vswitch;
		my %existingvSwitch;
		foreach(@$currentvSwitches) {
			if(!$existingvSwitch{$_->name}) {
				$existingvSwitch{$_->name} = "yes";	
			}
		}	
		
		print color("green") . "\tApplying Network vSwitch configurations ...\n" . color("reset");
		foreach my $vSwitch (@$vSwitches) {
			my $vSwitchName = $vSwitch->name;
			my $vSwitchSpec = $vSwitch->spec;
			if(!$existingvSwitch{$vSwitchName}) {
				eval {
					$networkSys->AddVirtualSwitch(vswitchName => $vSwitchName, spec => $vSwitchSpec);
				};
        		        if($@) {
	                	        print color("red") . "\tUnable to add Network vSwitch Configurations for: \"$vSwitchName\"! - $@\n" . color("reset");
					&stopScript();
                		}
			} else {
				eval {
					$networkSys->UpdateVirtualSwitch(vswitchName => $vSwitchName, spec => $vSwitchSpec);	
				};
				if($@) {
                                        print color("red") . "\tUnable to update existing Network vSwitch Configurations for: \"$vSwitchName\"! - $@\n" . color("reset");
					&stopScript();
                                }
			}
		}
		print color("green") . "\t\tSuccessfully completed!\n" . color("reset");
	} else {
                print color("yellow") . "No Network vSwitch configurations found!\n" . color("reset");
        }
}

sub configureNetworkPortgroup {
        my ($profiledata,$host) = @_;

        if($profiledata) {
                my $portgroups = $profiledata;

                my $networkSys = &getNetworkSystem($host);
                my $currentPortgroups = $networkSys->networkConfig->portgroup;
                my %existingPortgroups;

		print color("green") . "\tApplying Network Portgroup configurations ...\n" . color("reset");

                foreach(@$currentPortgroups) {
                        if(!$existingPortgroups{$_->spec->name}) {
				my $portgroup_name = $_->spec->name;
				my $operation;
				my $notConfirm = 1;
                                while($notConfirm) {
					$operation = &promptUser("Found \"$portgroup_name\" [keep|delete|rename]");
					if($operation =~ m/keep/ || $operation =~ m/delete/ || $operation =~ m/rename/) {
                                        	$notConfirm = 0;
                                        }
				}

				if($operation =~ m/rename/) {
					my $newname;
					my $notVerify = 1;
					while($notVerify) {
						$newname = &promptUser("What would you like to rename \"$portgroup_name\" to");
						my $confirm = &promptUser("Confirm rename from \"$portgroup_name\" to \"$newname\" [yes|no]");
						if($confirm =~ m/yes/) {
							$notVerify = 0;
						}
					}			

					eval {
						my $hostPortgroupSpec = HostPortGroupSpec->new(name => $newname, policy => $_->spec->policy, vlanId => $_->spec->vlanId, vswitchName => $_->spec->vswitchName);
						$networkSys->UpdatePortGroup(pgName => $portgroup_name, portgrp => $hostPortgroupSpec);
						$networkSys->RefreshNetworkSystem();
						$existingPortgroups{$newname} = "yes";
					};
					if($@) {
						print color("red") . "\tUnable to rename \"$portgroup_name\"! - $@\n" . color("reset");
						&stopScript();
					}
				} elsif($operation =~ m/delete/) {
					eval {
                                                $networkSys->RemovePortGroup(pgName => $portgroup_name);
                                        };
                                        if($@) {
                                                print color("red") . "\tUnable to delete \"$portgroup_name\"! - $@\n" . color("reset");
						&stopScript();
                                        }
				} else {
                                	$existingPortgroups{$_->spec->name} = "yes";
				}
                        }
                }

                foreach my $portgroup (@$portgroups) {
			my $portgroupName = $portgroup->spec->name;
                        if(!$existingPortgroups{$portgroupName}) {
                                eval {
                                        $networkSys->AddPortGroup(portgrp => $portgroup->spec);
                                };
                                if($@) {
                                        print color("red") . "\tUnable to add Network portgroup Configurations for: \"$portgroupName\"! - $@\n" . color("reset");
					&stopScript();
                                }
                        } else {
                                eval {
					$networkSys = &getNetworkSystem($host);
		 	              	$currentPortgroups = $networkSys->networkConfig->portgroup;
					my $pg = &FindPortGroupbyName($currentPortgroups,$portgroupName);
					my $hostPortgroupSpec = HostPortGroupSpec->new(name => $pg->spec->name, policy => $portgroup->spec->policy, vlanId => $pg->spec->vlanId, vswitchName => $pg->spec->vswitchName);
					$networkSys->UpdatePortGroup(pgName => $portgroupName, portgrp => $hostPortgroupSpec);
                                };
                                if($@) {
                                        print color("red") . "\tUnable to update existing Network portgroup Configurations for: \"$portgroupName\"! - $@\n" . color("reset");
					&stopScript();
                                }
                        }
                }
		print color("green") . "\t\tSuccessfully completed!\n" . color("reset");
        } else {
                print color("yellow") . "No Network portgroup configurations found!\n" . color("reset");
        }
}

sub configureAdvOpt {
	my ($profiledata,$host) = @_;

        if($profiledata) {
		my $advOpts = $profiledata;
		my $advOptSys = &getAdvancedOptionSystem($host);
		my $currentOpts = $advOptSys->setting;
		
		my %existingAdvOpts = ();
		foreach(@$currentOpts) {
			my $key = $_->key;
			my $value = $_->value;
			if($key ne 'ScratchConfig.ConfiguredScratchLocation' && $key ne 'ScratchConfig.CurrentScratchLocation') {  
				$existingAdvOpts{$key} = $value;
			}
		}

		print color("green") . "\tApplying Advanced Setting configurations ...\n" . color("reset");
		foreach(@$advOpts) {
			my $key = $_->key;
			my $value = $_->value;
			if($existingAdvOpts{$key}) {
				if($existingAdvOpts{$key} ne $value && $key ne 'ScratchConfig.ConfiguredScratchLocation' && $key ne 'ScratchConfig.CurrentScratchLocation') {
					eval {
						my $optVal = OptionValue->new(key => $key, value => $value);
						$advOptSys->UpdateOptions(changedValue => [$optVal]);
					};
					if($@) {
			                        print color("red") . "\tUnable to update advanced settings \"".$key."\" with value \"".$value."\"  for host! - $@\n" . color("reset");
                       				&stopScript();
                			}
			}	}
		}
		print color("green") . "\t\tSuccessfully completed!\n" . color("reset");
        } else {
                print color("yellow") . "No Advanced Setting configurations found!\n" . color("reset");
        }
}

sub configureSNMP {
	my ($profiledata,$host) = @_;

        if($profiledata) {
		my $snmp = $profiledata;

		my $snmpSys = &getSNMPSystem($host);
		my $currentSNMP = $snmpSys;

		print color("green") . "\tApplying SNMP configurations ...\n" . color("reset");
		if($snmp ne $currentSNMP->configuration && $snmp->enabled) {
			eval {
				my $snmpSpec = HostSnmpConfigSpec->new(port => $snmp->port, readOnlyCommunities => $snmp->readOnlyCommunities, trapTargets => $snmp->trapTargets);
				$snmpSys->ReconfigureSnmpAgent(spec => $snmpSpec);

				my $enableSpec = HostSnmpConfigSpec->new(enabled => 1);
				$snmpSys->ReconfigureSnmpAgent(spec => $enableSpec);
			};
			if($@) {
                        	print color("red") . "\tUnable to reconfigure SNMP settings! - $@\n" . color("reset");
                                &stopScript();
                        }	
		}

	        print color("green") . "\t\tSuccessfully completed!\n" . color("reset");
        } else {
                print color("yellow") . "No SNMP configurations found!\n" . color("reset");
        }
}

sub configureService {
	my ($profiledata,$host) = @_;

	if($profiledata) {
		my $services = $profiledata;
		my $serviceSys = &getServiceSystem($host);
		my $currentServices = $serviceSys->serviceInfo->service;

		my %existingServcies = ();
		foreach(@$currentServices) {
			#ignore vmware-vpxa service
			if($_->key ne 'vmware-vpxa') {
				$existingServcies{$_->key} = $_;
			}
		}
		
		print color("green") . "\tApplying Servcice configurations ...\n" . color("reset");
		foreach(@$services) {
			if($existingServcies{$_->key}) {
				eval {
					#update policy
					$serviceSys->UpdateServicePolicy(id => $_->key, policy => $_->policy);
					$serviceSys->RefreshServices();
				};
				if($@) {
					print color("red") . "\tUnable to update policy for \"" . $_->key . "\"! - $@\n" . color("reset");
                        		&stopScript();
				}
			
				eval {	
					#check status
					if($_->running && !$existingServcies{$_->key}->running) {
						$serviceSys->StartService(id => $_->key);
					}elsif(!$_->running && $existingServcies{$_->key}->running) {
						$serviceSys->StopService(id => $_->key);
					}
				};
				if($@) {
					print color("red") . "\tUnable to change status for \"" . $_->key . "\"! - $@\n" . color("reset");
                                        &stopScript();
                                }
			}
		}
		print color("green") . "\t\tSuccessfully completed!\n" . color("reset");
	} else {
                print color("yellow") . "No Service configurations found!\n" . color("reset");
        }
}

sub configureLicense {
	my ($profiledata,$host) = @_;

        if($profiledata) {
                my $licenses = $profiledata;
                my $licenseSys = &getLicenseSystem($host);

                eval {
                        print color("green") . "\tApplying License configurations ...\n" . color("reset");
			foreach(@$licenses) {
				$licenseSys->UpdateLicense(licenseKey => $_);
			}
                        print color("green") . "\t\tSuccessfully completed!\n" . color("reset");
                };
                if($@) {
                        print color("red") . "\tUnable to set License Configurations! - $@\n" . color("reset");
                        &stopScript();
                }
        } else {
                print color("yellow") . "No License configurations found!\n" . color("reset");
        }
}

sub configureDateTime {
	my ($profiledata,$host) = @_;

	if($profiledata) {
		my $ntpServers = $profiledata;
		my $datetimeSys = &getDateTimeSystem($host);
		
		eval {
			print color("green") . "\tApplying Datetime configurations ...\n" . color("reset");	
			my $ntpConfig = HostNtpConfig->new(server => $ntpServers);
			my $dateTimeConfig = HostDateTimeConfig->new(ntpConfig => $ntpConfig);
			$datetimeSys->UpdateDateTimeConfig(config => $dateTimeConfig);
			$datetimeSys->RefreshDateTimeSystem();
			print color("green") . "\t\tSuccessfully completed!\n" . color("reset");
		};
		if($@) {
			print color("red") . "\tUnable to set NTP Server Configurations! - $@\n" . color("reset");
			&stopScript();
		}	
	} else {
		print color("yellow") . "No Datetime configurations found!\n" . color("reset");
	}
}

sub backupHost {
        my ($host) = @_;

	my $verify = &promptUser("Would you like to backup \"" . $host->name . "\" before getting started? [yes|no]");
        if($verify =~ m/yes/) {
		my $fwSys = Vim::get_view(mo_ref => $host->configManager->firmwareSystem);

        	my $downloadUrl;
	        eval {
        	        $downloadUrl = $fwSys->BackupFirmwareConfiguration();
        	};
        	if ($@) {
			print color("red") . "Error: Failed to backup ESXi configurations! - $@->fault_string\n" . color("reset");
        	}
		my $file = $host->name . ".backup";
		print color("green") . "\tSuccessfully backed up ESXi host configuration to \"$file\"\n" . color("reset");
        	if ($downloadUrl =~ m@http.*//\*//?(.*)@) {
                	my $docrootPath = $1;
	                unless (defined($file)) {
        	        # strips off all the directory parts of the url
                	($file = $docrootPath) =~ s/.*\///g
	        }
        	VIExt::http_get_file("docroot", $docrootPath, undef, undef, $file);
	        } else {
        	        print color("red") . "Error: Unexpected download URL format: $downloadUrl\n" . color("reset");
        	}
	}
}

sub parseMetaData {
	my ($profiledata,$host) = @_;

	print color("cyan") . "\nWould you like to apply the following ghettoHostProfile to \"" . $host->name . "\"?\n\n" . color("reset");

	my %metadata = %$profiledata;

	print color("cyan") . "Base Profile: " . color("reset") . $metadata{'profile-base'} . "\n";
	print color("cyan") . "Profile Description: " . color("reset") . $metadata{'description'} . "\n";
	print color("cyan") . "Profile Export Date: " . color("reset") . $metadata{'export-date'} . "\n\n";	

	my $verify = &promptUser("Please Confirm? [yes|no]");
	if($verify !~ m/yes/) {
		&stopScript();
	}
}

sub rebootHost {
	my ($host) = @_;

	print "For all changes to take full effect, please reboot the host\n";
        my $verify = &promptUser("Would you like to reboot now? [yes|no]");
        if($verify =~ m/yes/) {
		print color("yellow") . "Rebooting " . $host->name . " now ...\n" . color("reset");
        	my $task = $host->RebootHost_Task(force => 0);
                &waitOnTask($task);
        }
}

sub verifyMaintenanceMode {
	my ($host) = @_;

	if(!$host->runtime->inMaintenanceMode) {
		print color("red") . "Error: Host must be in maintenance mode before profile can be applied!\n" . color("reset");
		my $verify = &promptUser("Would you like to enter maintenance mode now? [yes|no]");
		if($verify =~ m/yes/) {
			my $task = $host->EnterMaintenanceMode_Task(timeout => 0);
			&waitOnTask($task);
	        } else {
			&stopScript();
		}
	}
}

sub getMetaData {
	my ($host) = @_;

	if(!$description) {
		$description = "Profile exported from " . $host->name;
	}

        my %hash = ('profile-base',$host->name,'description',$description,'export-date',&giveMeDate('MDYHMS'));
	my $hashRef = \%hash;
	return $hashRef;
}

sub getAdvancedOptionSystemConfig {
	my ($host) = @_;

	print color("green") . "\tExporting Advanced Option configurations ...\n" . color("reset");
        my $advOpSys = &getAdvancedOptionSystem($host);
	my $settings = $advOpSys->setting;

	return $settings;
}

sub getAdvancedOptionSystem {
	my ($host) = @_;

	return Vim::get_view(mo_ref => $host->configManager->advancedOption);
}

sub getSNMPSystemConfig {
	my ($host) = @_;

        print color("green") . "\tExporting SNMP configurations ...\n" . color("reset");
	my $snmp = &getSNMPSystem($host);

	my @snmp_info;
        push @snmp_info, $snmp->configuration;
        my $snmpRef = \@snmp_info;

	return $snmp->configuration;
        #return $snmpRef;
}

sub getSNMPSystem {
	my ($host) = @_;

        return Vim::get_view(mo_ref => $host->configManager->snmpSystem);
}

sub getServiceSystemConfig {
	my ($host) = @_;

	print color("green") . "\tExporting Service configurations ...\n" . color("reset");
        my $serviceSys = &getServiceSystem($host);
	my $services = $serviceSys->serviceInfo->service;

	return $services;
}

sub getServiceSystem {
        my ($host) = @_;

        return Vim::get_view(mo_ref => $host->configManager->serviceSystem);
}

sub getVirtualNicSystemConfig {
	my ($host) = @_;

	print color("green") . "\tExporting Virtual NIC configurations ...\n" . color("reset");
        my $virtualNicSys = &getVirtualNicSystem($host);
	my $vnic_config = $virtualNicSys->info->netConfig;	

	return $vnic_config;
}

sub getVirtualNicSystem {
        my ($host) = @_;

        return Vim::get_view(mo_ref => $host->configManager->virtualNicManager);
}

sub getLicenseSystemConfig {
	my ($host) = @_;

	print color("green") . "\tExporting License configuration ...\n" . color("reset");
        my $licenseSys = &getLicenseSystem($host);
	my $licenses = $licenseSys->{'licenses'};

	my @license_info;
	foreach(@$licenses) {
		push @license_info, $_->licenseKey;
	}

	my $arrRef = \@license_info;
	return $arrRef;
}

sub getLicenseSystem {
	my ($host) = @_;

        return Vim::get_view(mo_ref => $host->configManager->licenseManager, properties => ['licenses']);
}

sub getDatastoreSystemConfig {
	my ($host) = @_;

	print color("green") . "\tExporting Datastore configuration ...\n" . color("reset");
        my $datastoreSys = &getDatastoreSystem($host);
	my $datastores = Vim::get_views(mo_ref_array => $datastoreSys->datastore, properties => ['info']);

	my @datastore_info;
	foreach(@$datastores) {
		push @datastore_info, $_->{'info'};	
	}
	my $dsRef = \@datastore_info;

	return $dsRef;
}

sub getDatastoreSystem {
        my ($host) = @_;

        return Vim::get_view(mo_ref => $host->configManager->datastoreSystem);
}

sub getStorageSystemConfig {
        my ($host) = @_;

        print color("green") . "\tExporting Storage configuration ...\n" . color("reset");
        my $storageSys = &getStorageSystem($host);
        my $storages = $storageSys->storageDeviceInfo;

        my @storage_info;
        push @storage_info, $storages;
        my $storageRef = \@storage_info;

        return $storageRef;
}

sub getStorageSystem {
	my ($host) = @_;

        return Vim::get_view(mo_ref => $host->configManager->storageSystem);
}

sub getNetworkSystemPortgroupConfig {
	my ($host) = @_;

        print color("green") . "\tExporting Network Portgroup configuration ...\n" . color("reset");
        my $networkSys = &getNetworkSystem($host);
        my $portgroups = $networkSys->networkConfig->portgroup;

        return $portgroups;
}

sub getNetworkSystemvSwitchConfig {
	my ($host) = @_;

	print color("green") . "\tExporting Network vSwitch configuration ...\n" . color("reset");
        my $networkSys = &getNetworkSystem($host);
	my $vswitches = $networkSys->networkConfig->vswitch;

	return $vswitches;
}

sub getNetworkSystem {
	my ($host) = @_;

        return Vim::get_view(mo_ref => $host->configManager->networkSystem);
}	

sub getDateTimeSystemConfig {
	my ($host) = @_;

	print color("green") . "\tExporting Datetime configurations ...\n" . color("reset");
	my $datetimeSys = &getDateTimeSystem($host);
	my $ntpServers = $datetimeSys->dateTimeInfo->ntpConfig->server;

	return $ntpServers;
}

sub getDateTimeSystem {
	my ($host) = @_;

        return Vim::get_view(mo_ref => $host->configManager->dateTimeSystem);
}

#burrowed from esxcfg-vswitch
sub FindPortGroupbyName {
	my ($portgroups,$pgName) = @_;

	foreach my $pg (@$portgroups) {
		my $spec = $pg->spec;
		return $pg if (($spec->name eq $pgName));
	}	
}

sub waitOnTask {
	my ($taskRef) = @_;
	my $task_view = Vim::get_view(mo_ref => $taskRef);
        my $taskinfo = $task_view->info->state->val;
        my $continue = 1;
        while ($continue) {
                my $info = $task_view->info;
                if ($info->state->val eq 'success') {
                        return $info->result;
                        $continue = 0;
                } elsif ($info->state->val eq 'error') {
                        my $soap_fault = SoapFault->new;
                        $soap_fault->name($info->error->fault);
                        $soap_fault->detail($info->error->fault);
                        $soap_fault->fault_string($info->error->localizedMessage);
                        print color("red") . "\tError: $soap_fault\n" . color("reset");
                }
                sleep 5;
                $task_view->ViewBase::update_view_data();
        }
}

sub stopScript {
	Util::disconnect();
	print "\nExiting script ...\n";
	exit 1;	
}

sub generatedmd5sum {
	my ($profilename) = @_;

	my $md5file = $profilename . $md5ext;
	print color("yellow") . "\tGenerating MD5 checksum on ghettoHostProfile: \"$profilename\"\n" . color("reset");
	eval {
		my $md5 = `/usr/bin/md5sum $profilename > $md5file`;
	};
	if($@) {
		print color("red") . "\tUnable to generated MD5 checksum on \"$profilename\"! - $@\n" . color("reset");
		&stopScript();	
	} else {
		print color("green") . "\tSuccessfully generated MD5 checksum file \"$md5file\"!\n" . color("reset");
	}
}

sub verifymd5sum {
	my ($profilename) = @_;

	my $md5file = $profilename . $md5ext;
	print color("yellow") . "\nVerifying MD5 checksum on ghettoHostProfile: \"$profilename\"\n" . color("reset");
	eval {
                my $md5 = `/usr/bin/md5sum -c $md5file`;
		if($md5 =~ m/OK/) {
			print color("green") . "Successfully verified MD5 checksum file \"$md5file\"!\n" . color("reset");
		} else {
			print color("red") . "Verification of MD5 checksum failed for \"$profilename\"! Profile potentially corrupt!\n" . color("reset");
			&stopScript();
		}
        };
        if($@) {
                print color("red") . "\tUnable to verify MD5 checksum on \"$profilename\"! - $@\n" . color("reset");
                &stopScript();
        }
}

sub giveMeDate {
        my ($date_format) = @_;
        my %dttime = ();
        my $my_time;
        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);

        ### begin_: initialize DateTime number formats
        $dttime{year }  = sprintf "%04d",($year + 1900);  ## four digits to specify the year
        $dttime{mon  }  = sprintf "%02d",($mon + 1);      ## zeropad months
        $dttime{mday }  = sprintf "%02d",$mday;           ## zeropad day of the month
        $dttime{wday }  = sprintf "%02d",$wday + 1;       ## zeropad day of week; sunday = 1;
        $dttime{yday }  = sprintf "%02d",$yday;           ## zeropad nth day of the year
        $dttime{hour }  = sprintf "%02d",$hour;           ## zeropad hour
        $dttime{min  }  = sprintf "%02d",$min;            ## zeropad minutes
        $dttime{sec  }  = sprintf "%02d",$sec;            ## zeropad seconds
        $dttime{isdst}  = $isdst;

        if($date_format eq 'MDYHMS') {
                $my_time = "$dttime{mon}-$dttime{mday}-$dttime{year} $dttime{hour}:$dttime{min}:$dttime{sec}";
        }
        elsif ($date_format eq 'YMD') {
                $my_time = "$dttime{year}-$dttime{mon}-$dttime{mday}";
        }
        return $my_time;
}

# restrict the number of digits after the decimal point
#http://guymal.com/mycode/perl_restrict_digits.shtml
sub restrict_num_decimal_digits {
        my $num=shift;#the number to work on
        my $digs_to_cut=shift;# the number of digits after

        if ($num=~/\d+\.(\d){$digs_to_cut,}/) {
                $num=sprintf("%.".($digs_to_cut-1)."f", $num);
        }
        return $num;
}

# prompt user taken from http://devdaily.com/perl/edu/articles/pl010005#comment-159
sub promptUser {
  	my($prompt) = @_;
	print color("black","on_yellow") . "\t$prompt:" . color("reset") . " ";
  	chomp(my $input = <STDIN>);
	return $input;
}

sub validateConnection {
        my ($host_version,$host_license,$host_type) = @_;
        my $service_content = Vim::get_service_content();
        my $licMgr = Vim::get_view(mo_ref => $service_content->licenseManager);

	########################
	# ESXi only
	########################
	if($service_content->about->productLineId ne "embeddedEsx") {
		Util::disconnect();
                print "This script will only work on ESXi\n\n";
                exit 1;
	}

        ########################
        # CHECK HOST VERSION
        ########################
        if(!$service_content->about->version ge $host_version) {
                Util::disconnect();
                print "This script requires your ESXi host to be greater than $host_version\n\n";
                exit 1;
        }

        ########################
        # CHECK HOST LICENSE
        ########################
        my $licenses = $licMgr->licenses;
        foreach(@$licenses) {
                if($_->editionKey eq 'esxBasic' && $host_license eq 'licensed') {
                        Util::disconnect();
                        print "This script requires your ESXi be licensed, the free version will not allow you to perform any write operations!\n\n";
                        exit 1;
                }
        }

        ########################
        # CHECK HOST TYPE
        ########################
        if($service_content->about->apiType ne $host_type && $host_type ne 'both') {
                Util::disconnect();
                print "This script needs to be executed against $host_type\n\n";
                exit 1
        }

        return $service_content->about->apiType;
}
