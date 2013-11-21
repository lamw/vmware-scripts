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

##################################################################
# Author: William Lam
# 06/06/2009
# http://www.engineering.ucsb.edu/~duonglt/vmware/
# http://communities.vmware.com/docs/DOC-10112
# Orignal code based off of: http://communities.vmware.com/message/840944#840944
##################################################################
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
