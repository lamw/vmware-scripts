#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://communities.vmware.com/docs/DOC-10112

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;

my %opts = (
        'vmname' => {
        type => "=s",
        help => "The name of the virtual machine",
        required => 1,
        },
        'vnic' => {
        type => "=s",
        help => "vNIC Adapter # (e.g. 1,2,3,etc)",
        required => 1,
        },
        'portgroup' => {
        type => "=s",
        help => "Portgroup to add",
        required => 1,
        },
);
# validate options, and connect to the server
Opts::add_options(%opts);

# validate options, and connect to the server
Opts::parse();
Opts::validate();
Util::connect();

my $vnic_device;
my $vmname = Opts::get_option ('vmname');
my $vnic = Opts::get_option ('vnic');
my $portgroup = Opts::get_option ('portgroup');

my $vm_view  = Vim::find_entity_view (view_type => 'VirtualMachine', filter =>{ 'name'=> $vmname});

if ($vm_view) {
        my $config_spec_operation = VirtualDeviceConfigSpecOperation->new('edit');
        my $devices = $vm_view->config->hardware->device;
        my $vnic_name = "Network adapter $vnic";

        foreach my $device (@$devices) {
                if ($device->deviceInfo->label eq $vnic_name){
                        $vnic_device=$device;
                }
        }
        if($vnic_device){
                $vnic_device->deviceInfo->summary($portgroup);
                $vnic_device->backing->deviceName($portgroup);
                my $vm_dev_spec = VirtualDeviceConfigSpec->new(device => $vnic_device,operation => $config_spec_operation);

                my $vmPortgroupChangespec = VirtualMachineConfigSpec->new(deviceChange => [ $vm_dev_spec ] );

                eval{
                        $vm_view->ReconfigVM(spec => $vmPortgroupChangespec);
                };
                if ($@) {
                        print "Reconfiguration of portgroup \"$portgroup\" failed.\n $@";
                }
                else {
                        $vm_view->update_view_data();
                        print "Reconfiguration of portgroup \"$portgroup\" successful for \"$vmname\".\n";
                }
        } else {
                print "Unable to find $vnic_name\n";
        }
} else {
        Util::trace(0,"\nUnable to locate $vmname!\n");
        exit 0;
}

Util::disconnect();
