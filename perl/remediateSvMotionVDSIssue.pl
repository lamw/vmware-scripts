#!/usr/bin/perl -w
# Copyright (c) 2009-2012 William Lam All rights reserved.

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
# http://www.virtuallyghetto.com/

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;

my %opts = (
   vmfile => {
      type => "=s",
      help => "List of Virtal Machines to remediate VDS DvPort Issue",
      required => 1,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $vmfile = Opts::get_option('vmfile');
my @vmList = ();
my %tmpDvPortgroupsToVDSMapping = ();
my %tmpDvPortgroupsKeyMapping = ();
my %orgDvPortgroupsKeyMapping = ();
my %dvPortgroupsToDelete = ();
my $debug = 0;
my $vm_view;

&processFile($vmfile);

my $vdsMgr = Vim::get_view(mo_ref => Vim::get_service_content()->dvSwitchManager);

foreach my $vm (@vmList) {
	$vm_view = Vim::find_entity_view(view_type => 'VirtualMachine', filter => {'name' => $vm}, properties => ['name','network','config.hardware.device']);
	if($vm_view) {
		my $vmNetworks = $vm_view->{'network'};
		my $vmDevices = $vm_view->{'config.hardware.device'};		
		
		print "\nRemediating " . $vm . "...\n";
		&createTempDvPortgroups($vmNetworks);
		&reconfigDvPortgroups($vmDevices);
	} else {
		print "Unable to find VM: " . $vm . "\n";
	}
	%tmpDvPortgroupsToVDSMapping = ();
	print "Remediation completed for " . $vm . "\n";
}
# delete all temp dvportgroups that were created early
&deleteTempDvPortgroups();

Util::disconnect();

sub reconfigDvPortgroups {
	my ($vmDevices) = @_;

	# change the VM networks to the temp dvportgroups
	my @deviceChange = ();
	foreach my $device (@$vmDevices) {
        	if($device->isa('VirtualEthernetCard')) {
                	if($device->backing->isa('VirtualEthernetCardDistributedVirtualPortBackingInfo')) {
                        	my $config_spec_operation = VirtualDeviceConfigSpecOperation->new('edit');
				my $vds = $vdsMgr->QueryDvsByUuid(uuid => $device->backing->port->switchUuid);
				my $vdsRef = Vim::get_view(mo_ref => $vds);
                                my $new = &findDvPortgroup($tmpDvPortgroupsKeyMapping{$device->backing->port->portgroupKey},$vdsRef);
                                my $port = DistributedVirtualSwitchPortConnection->new(portgroupKey => $new->{'key'}, switchUuid => $vdsRef->uuid);

                                my $dvPortgroupBacking = VirtualEthernetCardDistributedVirtualPortBackingInfo->new(port => $port);
                                $device->backing($dvPortgroupBacking);
                                my $vm_dev_spec = VirtualDeviceConfigSpec->new(device => $device, operation => $config_spec_operation);
                                push @deviceChange,$vm_dev_spec
                        }
                }
	}
        my $vmPortgroupChangespec = VirtualMachineConfigSpec->new(deviceChange => \@deviceChange );
       	eval {
                my $task = $vm_view->ReconfigVM_Task(spec => $vmPortgroupChangespec);
		&getStatus($task,"Reconfiguring VM to temporarily dvportgroups ...");
        };
        if($@) {
        	print "Error: Unable to reconfigure to temporarily dvportgroups " . $@ . "\n";
		Util::disconnect();
		exit 1;
	}

	# refresh the VM object
	@deviceChange = ();
	$vm_view->ViewBase::update_view_data();
	$vmDevices = $vm_view->{'config.hardware.device'};

	# change the VM networks back to original dvportgroups
	foreach my $device (@$vmDevices) {
                if($device->isa('VirtualEthernetCard')) {
                        if($device->backing->isa('VirtualEthernetCardDistributedVirtualPortBackingInfo')) {
				my $config_spec_operation = VirtualDeviceConfigSpecOperation->new('edit');
                                my $vds = $vdsMgr->QueryDvsByUuid(uuid => $device->backing->port->switchUuid);
                                my $vdsRef = Vim::get_view(mo_ref => $vds);
				my $name = $orgDvPortgroupsKeyMapping{$device->backing->port->portgroupKey};
                                my $new = &findDvPortgroup($name,$vdsRef);
                                my $port = DistributedVirtualSwitchPortConnection->new(portgroupKey => $new->{'key'}, switchUuid => $vdsRef->uuid);

                                my $dvPortgroupBacking = VirtualEthernetCardDistributedVirtualPortBackingInfo->new(port => $port);
                                $device->backing($dvPortgroupBacking);
                                my $vm_dev_spec = VirtualDeviceConfigSpec->new(device => $device, operation => $config_spec_operation);
                                push @deviceChange,$vm_dev_spec
			}
		}
	}
	$vmPortgroupChangespec = VirtualMachineConfigSpec->new(deviceChange => \@deviceChange );
        eval {
                my $task = $vm_view->ReconfigVM_Task(spec => $vmPortgroupChangespec);
		&getStatus($task,"Reconfiguring VM to original dvportgroups ...");
        };
        if($@) {
                print "Error: Unable to reconfigure to original dvportgroups " . $@ . "\n";
		Util::disconnect();
		exit 1;
        }
}

sub createTempDvPortgroups {
	my ($vmNetworks) = @_;
	
	foreach my $vmNetwork (@$vmNetworks) {
		my $vmNetwork_view = Vim::get_view(mo_ref => $vmNetwork);
		if($vmNetwork_view->isa('DistributedVirtualPortgroup')) {
        	        my $vds_view = Vim::get_view(mo_ref => $vmNetwork_view->config->distributedVirtualSwitch);
                	my $dvPortgroupName = $vmNetwork_view->name;
	                my $tmpdvPortgroupName = "TEMP-" . $dvPortgroupName;
        	        my $vdsName = $vds_view->name;
                	if($debug) {
                        	print "DvPortgroup: " . $dvPortgroupName . "\n";
	                        print "TempDvPortgroup: " . $tmpdvPortgroupName . "\n";
        	                print "VDS: " . $vdsName . "\n\n";
                	}
			my $newDvPortGroupKey;
        	        # create temp dvPortgroup on VDS & keep track of the ones created base on name 
                	if(!$dvPortgroupsToDelete{$tmpdvPortgroupName}) {
				# keep track of the same dvportgroup being created
				$tmpDvPortgroupsToVDSMapping{$tmpdvPortgroupName} = $vds_view;
				# used for deletes at the end
				$dvPortgroupsToDelete{$tmpdvPortgroupName} = $vds_view;

				# create mew dvportgroup based on the existig configuration
        	        	eval {
                	        	my $spec = DVPortgroupConfigSpec->new(
                        	        	autoExpand => $vmNetwork_view->config->autoExpand,
                                	        defaultPortConfig => $vmNetwork_view->config->defaultPortConfig,
                                        	name => $tmpdvPortgroupName,
	                                        numPorts => $vmNetwork_view->config->numPorts,
        	                                policy => $vmNetwork_view->config->policy,
                	                        type => $vmNetwork_view->config->type
                        	        );
                                	my $task = $vds_view->AddDVPortgroup_Task(spec => [$spec]);
	                                my $msg = "\tCreating " . $tmpdvPortgroupName . " ...";
        	                        &getStatus($task,$msg);

					# retrieve the new dvportgroup key that we just created
					my $taskRef = Vim::get_view(mo_ref => $task);
					my $vdsRef = Vim::get_view(mo_ref => $taskRef->info->entity);
					my $newDvPortGroup = &findDvPortgroup($tmpdvPortgroupName,$vdsRef);
					$newDvPortGroupKey = $newDvPortGroup->key;
	                        };
        	                if($@) {
                	        	print "Error: Unable to create dvPortgroup " . $@ . "\n";
	                        }
				# hash table containing the DvPortgroup key to dvPortgroupName
				$tmpDvPortgroupsKeyMapping{$vmNetwork_view->key} = $tmpdvPortgroupName;
				$orgDvPortgroupsKeyMapping{$newDvPortGroupKey} = $dvPortgroupName;
			}
		}
	}
}

sub deleteTempDvPortgroups {
	foreach my $key ( keys %dvPortgroupsToDelete ) {
		my $value = $dvPortgroupsToDelete{$key};
		my $dvPortgroupView = &findDvPortgroup($key,$value);
		my $msg = "\tRemoving " . $key . "...";
		my $task = $dvPortgroupView->Destroy_Task();
		&getStatus($task,$msg);
	}
}

sub findDvPortgroup {
	my ($name,$vds) = @_;

	my $dvpg = undef;

	$vds->ViewBase::update_view_data();
	my $dvPortgroups = $vds->portgroup;
	foreach my $dvPortgroup (@$dvPortgroups) {
		my $dvPortgroupView = Vim::get_view(mo_ref => $dvPortgroup, properties => ['name','key']);
		if($name eq $dvPortgroupView->{'name'}) {
			$dvpg = $dvPortgroupView;
			last;
		}
	}
	return $dvpg;
}

sub getStatus {
        my ($taskRef,$message) = @_;

        my $task_view = Vim::get_view(mo_ref => $taskRef);
        my $taskinfo = $task_view->info->state->val;
        my $continue = 1;
        while ($continue) {
                my $info = $task_view->info;
                if ($info->state->val eq 'success') {
			print $message . "\n";
                        $continue = 0;
                } elsif ($info->state->val eq 'error') {
                        my $soap_fault = SoapFault->new;
                        $soap_fault->name($info->error->fault);
                        $soap_fault->detail($info->error->fault);
                        $soap_fault->fault_string($info->error->localizedMessage);
                        die "$soap_fault\n";
                }
                sleep 1;
                $task_view->ViewBase::update_view_data();
        }
}

# Subroutine to process the input file
sub processFile {
        my ($conf) = @_;

        open(CONFIG, "$conf") || die "Error: Couldn't open the $conf!";
        while (<CONFIG>) {
                chomp;
                s/#.*//; # Remove comments
                s/^\s+//; # Remove opening whitespace
                s/\s+$//;  # Remove closing whitespace
                next unless length;
                chomp($_);
		push @vmList,$_;
        }
        close(CONFIG);
}
