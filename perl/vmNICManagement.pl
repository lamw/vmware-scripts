#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://www.virtuallyghetto.com/2011/07/2-hidden-virtual-machine-gems-in.html

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;

my %opts = (
        'vmname' => {
        	type => "=s",
	        help => "The name of the virtual machine to apply operation",
        	required => 1,
        },
        'vnic' => {
	        type => "=s",
        	help => "vNIC Adapter # (e.g. 1,2,3,etc)",
	        required => 1,
        },
	'operation' => {
		type => "=s",
                help => "[query|updatemac|updatenictype]",
                required => 1,
	},
        'nictype' => {
	        type => "=s",
        	help => "pcnet|vmxnet2|vmxnet3|e1000|e1000e",
	        required => 0,
        },
	'mac' => {
                type => "=s",
                help => "New MAC Address to set",
                required => 0,
        },
);
# validate options, and connect to the server
Opts::add_options(%opts);

# validate options, and connect to the server
Opts::parse();
Opts::validate();
Util::connect();

my $apiVer = Vim::get_service_content()->about->version;

my $vnic_device;
my $vmname = Opts::get_option ('vmname');
my $vnic = Opts::get_option ('vnic');
my $operation = Opts::get_option ('operation');
my $nictype = Opts::get_option ('nictype');
my $mac = Opts::get_option ('mac');

my $vm_view = Vim::find_entity_view(view_type => 'VirtualMachine', filter =>{ 'name' => $vmname});

if ($vm_view) {
	if($vm_view->runtime->powerState->val ne 'poweredOff') {
		Util::disconnect();
		die "VM is still powered on or in suspend mode, please shutdown and try again!\n";
	}

        my $devices = $vm_view->config->hardware->device;
        my $vnic_name = "Network adapter $vnic";

        foreach my $device (@$devices) {
                if ($device->deviceInfo->label eq $vnic_name){
                        $vnic_device=$device;
                }
        }

        #get information about the current vNIC
        if($vnic_device){
		if($operation eq 'query') {
			&query($vnic_device,$vnic_name,$vm_view);	
		}elsif($operation eq 'updatemac') {
			unless($mac) {
				Util::disconnect();
				print "Error: operation \"updatemac\" requires --mac parameter!\n";
				exit 1;
			}
			if($mac !~ /00:50:56/) {
				Util::disconnect();
                                print "Error: Invalid MAC Address entry - Valid range are between 00:50:56::00:00:00 and 00:50:56:3f:ff:ff!\n";
                                exit 1;
			}
			&updatemac($vnic_device,$vnic_name,$vm_view,$mac);
		}elsif($operation eq 'updatenictype') {
			unless($nictype) {
                                Util::disconnect();
                                print "Error: operation \"updatenictype\" requires --nictype parameter!\n";
                                exit 1;
                        }
			&updatenictype($vnic_device,$vnic_name,$vm_view,$nictype);
		} else {
			print "Error: Invalid operation!\n";
		}
        } else {
                print "Unable to find $vnic_name\n";
        }
} else {
        print "Unable to locate $vmname!\n";
        exit 0;
}

Util::disconnect();

sub query() {
	my ($vnic_device,$vnic_name,$vm_view) = @_;

	my $currMac = $vnic_device->macAddress;
        my $network = Vim::get_view(mo_ref => $vnic_device->backing->network, properties => ['name']);

	print "\nVM: " . $vm_view->name . "\n";
        print "Current info for \"" . $vnic_name . "\" which is using " . ref($vnic_device) . ":\n";
        print "MAC Address: " . $currMac . "\n";
        print "Network: " . $network->{'name'} . "\n\n";
}

sub updatemac() {
	my ($vnic_device,$vnic_name,$vm_view,$mac) = @_;

	my $currMac = $vnic_device->macAddress;
        my $network = Vim::get_view(mo_ref => $vnic_device->backing->network, properties => ['name']);

        print "Current info for \"" . $vnic_name . "\" which is using " . ref($vnic_device) . ":\n";
        print "MAC Address: " . $currMac . "\n";
        print "Network: " . $network->{'name'} . "\n\n";

        my $config_spec_operation = VirtualDeviceConfigSpecOperation->new('edit');
	my $backing_info = VirtualEthernetCardNetworkBackingInfo->new(deviceName => $network->{'name'});

        my $newNetworkDevice;

	my $nictype = ref($vnic_device);

        if($nictype eq 'VirtualE1000') {
                $newNetworkDevice = VirtualE1000->new(key => $vnic_device->key, unitNumber => $vnic_device->unitNumber, controllerKey => $vnic_device->controllerKey, backing => $backing_info, addressType => 'Manual', macAddress => $mac);
	} elsif($nictype eq 'VirtualE1000' && $apiVer eq "5.0.0") {
		$newNetworkDevice = VirtualE1000e->new(key => $vnic_device->key, unitNumber => $vnic_device->unitNumber, controllerKey => $vnic_device->controllerKey, backing => $backing_info, addressType => 'Manual', macAddress => $mac);
        } elsif($nictype eq 'VirtualPCNet32') {
                $newNetworkDevice = VirtualPCNet32->new(key => $vnic_device->key, unitNumber => $vnic_device->unitNumber, controllerKey => $vnic_device->controllerKey, backing => $backing_info, addressType => 'Manual', macAddress => $mac);
        } elsif($nictype eq 'VirtualVmxnet2') {
                $newNetworkDevice = VirtualVmxnet2->new(key => $vnic_device->key, unitNumber => $vnic_device->unitNumber, controllerKey => $vnic_device->controllerKey, backing => $backing_info, addressType => 'Manual', macAddress => $mac);
        } elsif($nictype eq 'VirtualVmxnet3') {
                $newNetworkDevice = VirtualVmxnet3->new(key => $vnic_device->key, unitNumber => $vnic_device->unitNumber, controllerKey => $vnic_device->controllerKey, backing => $backing_info, addressType => 'Manual', macAddress => $mac);
        } else {
                Util::disconnect();
                die "Unable to retrieve nictype!\n";
        }
	
	my $vm_dev_spec = VirtualDeviceConfigSpec->new(device => $newNetworkDevice, operation => $config_spec_operation);
        my $vmChangespec = VirtualMachineConfigSpec->new(deviceChange => [ $vm_dev_spec ] );
        my ($task_ref,$msg);

        eval{
                print "Updating MAC Address on vNic from \"$currMac\" to \"$mac\"\n";
                $task_ref = $vm_view->ReconfigVM_Task(spec => $vmChangespec);
                $msg = "\tSuccessfully reconfigured \"$vmname\"\n";
                &getStatus($task_ref,$msg);
        };
        if($@) {
                print "Error: " . $@ . "\n";
        }
}

sub updatenictype() {
	my ($vnic_device,$vnic_name,$vm_view,$nictype) = @_;

	my $currMac = $vnic_device->macAddress;
	my $network = Vim::get_view(mo_ref => $vnic_device->backing->network, properties => ['name']);
	my ($task_ref,$msg);

	if($nictype eq 'e1000e' && $vm_view->config->version ne "vmx-08") {
                Util::disconnect();
                print "\ne1000e vNIC is only supported on VMs that are Hardware Version 8\n";
                exit 1;
        }

        print "Current info for \"" . $vnic_name . "\" which is using " . ref($vnic_device) . ":\n";
        print "MAC Address: " . $currMac . "\n";
        print "Network: " . $network->{'name'} . "\n\n";

	#remove old vNIC
        my $config_spec_operation = VirtualDeviceConfigSpecOperation->new('remove');
        my $vm_dev_spec = VirtualDeviceConfigSpec->new(device => $vnic_device,operation => $config_spec_operation);

        my $vmChangespec = VirtualMachineConfigSpec->new(deviceChange => [ $vm_dev_spec ] );

        eval{
                print "Removing old " . ref($vnic_device) . " \"$vmname\".\n";
                $task_ref = $vm_view->ReconfigVM_Task(spec => $vmChangespec);
                $msg = "\tSuccessfully reconfigured \"$vmname\"\n";
                &getStatus($task_ref,$msg);
        };
        if($@) {
                print "Error: " . $@ . "\n";
        }

	#add new vNIC
        $config_spec_operation = VirtualDeviceConfigSpecOperation->new('add');
        my $backing_info = VirtualEthernetCardNetworkBackingInfo->new(deviceName => $network->{'name'});

        my $newNetworkDevice;
        if($nictype eq 'e1000') {
        	$newNetworkDevice = VirtualE1000->new(key => -1, backing => $backing_info, addressType => 'Manual', macAddress => $currMac);
	} elsif($nictype eq 'e1000e' && $apiVer eq "5.0.0") {
		$newNetworkDevice = VirtualE1000e->new(key => -1, backing => $backing_info, addressType => 'Manual', macAddress => $currMac);
        } elsif($nictype eq 'pcnet') {
                $newNetworkDevice = VirtualPCNet32->new(key => -1, backing => $backing_info, addressType => 'Manual', macAddress => $currMac);
        } elsif($nictype eq 'vmxnet2') {
                $newNetworkDevice = VirtualVmxnet2->new(key => -1, backing => $backing_info, addressType => 'Manual', macAddress => $currMac);
	} elsif($nictype eq 'vmxnet3') {
		$newNetworkDevice = VirtualVmxnet3->new(key => -1, backing => $backing_info, addressType => 'Manual', macAddress => $currMac);
        } else {
                Util::disconnect();
                die "Please select a valid nic type!\n";
        }

        $vm_dev_spec = VirtualDeviceConfigSpec->new(device => $newNetworkDevice, operation => $config_spec_operation);
        $vmChangespec = VirtualMachineConfigSpec->new(deviceChange => [ $vm_dev_spec ] );

        eval{
        	print "Adding new $nictype vNic to \"$vmname\"\n";
                $task_ref = $vm_view->ReconfigVM_Task(spec => $vmChangespec);
                $msg = "\tSuccessfully reconfigured \"$vmname\"";
                &getStatus($task_ref,$msg);
        };
        if($@) {
        	print "Error: " . $@ . "\n";
        }
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
