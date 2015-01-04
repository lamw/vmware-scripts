#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://www.virtuallyghetto.com/2012/04/identifying-virtual-machines-affected.html

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;

my %opts = (
   fix => {
      type => "=s",
      help => "[true|false]",
      required => 0,
      default => 'false',
   },
   vmname => {
      type => "=s",
      help => "Name of VM to manually remediate",
      required => 0,
   },
);

Opts::add_options(%opts);

Opts::parse();
Opts::validate();
Util::connect();

my $fix = Opts::get_option('fix');
my $vmname = Opts::get_option('vmname');

my $vdsMgr = Vim::get_view(mo_ref => Vim::get_service_content()->dvSwitchManager);
my $dvSwitches = Vim::find_entity_views(view_type => 'DistributedVirtualSwitch', properties => ['name','uuid','portgroup']);
my (%vmSeen,%dvPortgroupToVDSMapping) = ();
my $vm_view = undef;
my $debug = 0;

# map dvportgroup to vds, needed later on when reconfiguring
&mapDvPortgroupToVDS();

if($vmname && $fix eq "true") {
	$vm_view = Vim::find_entity_view(view_type => 'VirtualMachine', filter => {'name' => $vmname}, properties => ['config.hardware.device']);

	unless($vm_view) {
		print "Error: Unable to locate VM: " . $vmname . "\n";
		Util::disconnect();
		exit 1;
	}

	my $vmDevices = $vm_view->{'config.hardware.device'};
	&reconfigDvPort($vmDevices);
} else {
	foreach my $vds (@$dvSwitches) {
		print "Searching for VM's with Storage vMotion / VDS Issue ...\n";
		eval {
			# search for dvports that are connected
			my $vmCriteria = DistributedVirtualSwitchPortCriteria->new(connected => 'true');
		       	my $dvports = $vds->FetchDVPorts(criteria => $vmCriteria);
        		foreach my $dvport (@$dvports) {
				# search for only VMs connected to dvport
                		if($dvport->connectee && $dvport->connectee->connectedEntity->type eq "VirtualMachine") {
					$vm_view = Vim::get_view(mo_ref => $dvport->connectee->connectedEntity, properties => ['name','config.files.vmPathName','config.hardware.device','runtime.host']);
					my $vmConfigPath = $vm_view->{'config.files.vmPathName'};
					my ($datastoreName,$junk) = split(' ',$vmConfigPath);
					my $vmname = $vm_view->{'name'};
					my $host_view = Vim::get_view(mo_ref => $vm_view->{'runtime.host'}, properties => ['summary.config.product','datastoreBrowser']);
					# only valid for ESXi 5.0
					if($host_view->{'summary.config.product'}->version eq "5.0.0") {
						my $ds_browser = Vim::get_view(mo_ref => $host_view->{'datastoreBrowser'});
						# construct search path based on dvsData file
						my $path = $datastoreName . " .dvsData/" . $vds->{'uuid'};
	
						if($debug) {
							print $vmname . "\n";
							print $path . "\n";
						}

						# search datastore & match the expected dvsData file
						my $searchSpec = HostDatastoreBrowserSearchSpec->new(matchPattern => [$dvport->key]);	
						my $task = $ds_browser->SearchDatastoreSubFolders_Task(datastorePath => $path, searchSpec => $searchSpec);
						my $taskResult = &getResult($task,0,undef);

						# handle dvsData folder does not exists case (this is still a failure)
						if($taskResult->state->val eq "error") {
							if(ref($taskResult->error->fault) eq "FileNotFound") {
								if(!defined($vmSeen{$vmname})) {
									$vmSeen{$vmname} = "yes";
									print $vmname . " is currently impacted\n";
									if($fix eq "true") {
                                		                                print "\tRemediating " . $vmname . "\n";
                                        		                        my $vmDevices = $vm_view->{'config.hardware.device'};
                                                		                &reconfigDvPort($vmDevices);
										print "\tRemediation complete!\n\n";
	                                                        	}
								}
							} else {
								print "Unable to check VM " . $vmname . "\n";
							}
						# dvsData file does not exists
						} else {
							my $results = $taskResult->result;
							foreach my $result (@$results) {
								if(!defined($result->file) && !defined($vmSeen{$vmname})) {
									$vmSeen{$vmname} = "yes";
									print $vmname . " is currently impacted\n";
									if($fix eq "true") {
										print "\tRemediating " . $vmname . "\n";
										my $vmDevices = $vm_view->{'config.hardware.device'};
										&reconfigDvPort($vmDevices);
										print "\tRemediation complete!\n\n";
									}
								}		
								}
                        	        	}
					}
	                        }
			}
		};
		if($@) {
			print "ERROR: Unable to query for entities connected to dvSwitch " . $@ . "\n";
        	}
	}
}

Util::disconnect();

sub reconfigDvPort {
        my ($vmDevices) = @_;

	my ($originalPortKey,$newPortKey,$vds);
        # change the VM to another valid dvport in dvPortgroup
        foreach my $device (@$vmDevices) {
                if($device->isa('VirtualEthernetCard')) {
                        if($device->backing->isa('VirtualEthernetCardDistributedVirtualPortBackingInfo')) {
				$vds = $dvPortgroupToVDSMapping{$device->backing->port->portgroupKey};

				# ensure VM is connected to dvport
				if(defined($device->backing->port->portKey) && defined($vds)) {
					my ($dvPorts,$numPorts);
					my $dvPortgroup = &findDvPortgroup($device->backing->port->portgroupKey,$vds);
	
					# can only remediate Static or Dynamic bindings
					if($dvPortgroup->{'config.type'} eq "earlyBinding" || $dvPortgroup->{'config.type'} eq "lateBinding") {
						my $increase = 0;
					
                		                eval {
                                		        my $criteria = DistributedVirtualSwitchPortCriteria->new(active => 'false', connected => 'false', inside => 'true', portgroupKey => [$device->backing->port->portgroupKey], scope => $vm_view);
							my $dvPorts = $vds->FetchDVPorts(criteria => $criteria);
							# no more free ports
							if(@$dvPorts eq 0) {
								# store the current configured amount of ports
								$numPorts = $dvPortgroup->{'config.numPorts'};
								eval {
									# increase by 10 (for max ethernet interfaces for a VM)
									my $spec = DVPortgroupConfigSpec->new(numPorts => ($dvPortgroup->{'config.numPorts'} + 10), configVersion => $dvPortgroup->{'config.configVersion'});
									my $task = $dvPortgroup->ReconfigureDVPortgroup_Task(spec => $spec);
									&getResult($task,1,"\tSuccessfully increased ports for \"" . $dvPortgroup->{'name'} . "\" to " . ($dvPortgroup->{'config.numPorts'} + 10));
								};
								if($@) {
									print "Error: Unable to increase the ports on dvPortgroup " . $device->backing->port->portgroupKey . " " . $@ . "\n";
								} else {
									$increase = 1;
									$vds->ViewBase::update_view_data();
									$dvPorts = $vds->FetchDVPorts(criteria => $criteria);
								}
							}
							# select first free port
							my $freeDvPort = @$dvPorts[0];
							$originalPortKey = $device->backing->port->portKey;
							$newPortKey = $freeDvPort->key;
	                        	        };
        	                        	if($@) {
                		                        print "Error: Unable to fetch DvPorts" . $@ . "\n";
	                                	} else {
							print "\tMoving from dvPort: " . $originalPortKey . " to dvPort: " . $newPortKey . "\n";	
							&reconfigVM($device,$newPortKey,$vds->uuid);
							print "\tMoving from dvPort: " . $newPortKey . " back to dvPort: " . $originalPortKey . "\n";
                                        		&reconfigVM($device,$originalPortKey,$vds->uuid);
						}

						#clean up if we increased the number of ports
						if($increase) {
							$dvPortgroup = &findDvPortgroup($device->backing->port->portgroupKey,$vds);
							my $spec = DVPortgroupConfigSpec->new(numPorts => $numPorts, configVersion => $dvPortgroup->{'config.configVersion'});
							my $task;
							eval { 
								$task = $dvPortgroup->ReconfigureDVPortgroup_Task(spec => $spec);
								&getResult($task,1,"\tSuccessfully decreased the ports on \"" . $dvPortgroup->{'name'} . "\" to " . $numPorts);
							};
							if($@) {
								print "Error: Unable to decrease the ports on dvPortgroup " . $device->backing->port->portgroupKey . " " . $@ . "\n";
							}
						}
					} else {
						print "\tUnable to remediate " . $device->deviceInfo->label . " since dvportgroup is using ephemeral binding\n";
					}
				} else {
					print "\tUnable to remediate " . $device->deviceInfo->label . " as since dvportgroup is not initiliazed possibly due to dynamic or ephemeral binding\n";
				}
                        }
                }
        }
}

sub findDvPortgroup {
	my ($key,$vds) = @_;

	my $dvpg = undef;
	my $dvPortgroups = $vds->{'portgroup'};
	foreach my $dvPortgroup (@$dvPortgroups) {
		my $dvPortgroupView = Vim::get_view(mo_ref => $dvPortgroup, properties => ['name','config.key','config.type','config.numPorts','config.configVersion']);
		if($key eq $dvPortgroupView->{'config.key'}) {
			$dvpg = $dvPortgroupView;
			last;
		}
	}
	
	if(!$dvpg) {
		print "Unable to find dvPortgroupKey " . $key . "\n";
		Util::disconnect();
		exit 1;
	}
	return $dvpg;
}

sub reconfigVM {
	my ($device,$newPortKey,$vdsUuid) = @_;

	my $config_spec_operation = VirtualDeviceConfigSpecOperation->new('edit');
	my $port = DistributedVirtualSwitchPortConnection->new(portgroupKey => $device->backing->port->portgroupKey, portKey => $newPortKey, switchUuid => $vdsUuid);
        my $dvPortgroupBacking = VirtualEthernetCardDistributedVirtualPortBackingInfo->new(port => $port);
	$device->backing($dvPortgroupBacking);
        my $vm_dev_spec = VirtualDeviceConfigSpec->new(device => $device, operation => $config_spec_operation);
        my $vmPortgroupChangespec = VirtualMachineConfigSpec->new(deviceChange => [$vm_dev_spec]);
        eval {  
        	my $task = $vm_view->ReconfigVM_Task(spec => $vmPortgroupChangespec);
                &getResult($task,0,undef);
        };
        if($@) {
        	print "Error: Unable to reconfigure VM " . $@ . "\n"; 
        }

}

sub mapDvPortgroupToVDS {
	# map dvportgroup to vds, needed later on when reconfiguring
        foreach my $vds (@$dvSwitches) {
                my $dvPortgroups = Vim::get_views(mo_ref_array => $vds->{'portgroup'}, properties => ['name','key']);
                foreach my $dvPortgroup (@$dvPortgroups) {
                        $dvPortgroupToVDSMapping{$dvPortgroup->{'key'}} = $vds;
                }
        }
}

sub getResult {
        my ($taskRef,$print,$msg) = @_;

        my $task_view = Vim::get_view(mo_ref => $taskRef);
        my $taskinfo = $task_view->info->state->val;
        my $continue = 1;
        while ($continue) {
                my $info = $task_view->info;
                if ($info->state->val eq 'success') {
			if($print) {
				print $msg . "\n";
			}
			return $info;
                        $continue = 0;
                } elsif ($info->state->val eq 'error') {
			return $info;
			$continue = 0;
                }
                sleep 1;
                $task_view->ViewBase::update_view_data();
        }
}
