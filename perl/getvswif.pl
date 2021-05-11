#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://communities.vmware.com/docs/DOC-9852

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;

# read and validate command-line parameters
Opts::parse();
Opts::validate();
Util::connect();

my ($VSWIF,$PORTGROUP,$IP,$NETMASK,$MAC);

my $service_content = Vim::get_service_content();

if($service_content->about->productLineId eq 'esx') {
        format format1 =
@<<<<<<<<<<<<<<| @<<<<<<<<<<<<<<<<<<<<<<| @<<<<<<<<<<<<<<<<<| @<<<<<<<<<<<<<<<<<| @<<<<<<<<<<<<<<<<<<<<<<<<
$VSWIF,                          $PORTGROUP,           $IP,                $NETMASK,         $MAC
-----------------------------------------------------------------------------------------------------------
.
        ($VSWIF,$PORTGROUP,$IP,$NETMASK,$MAC) = ('VSWIF','PORTGROUP','IP','NETMASK','MAC');
        $~ = 'format1';
        write;

        my $host_view = Vim::find_entity_view(view_type => 'HostSystem');
        my $networkSys = Vim::get_view(mo_ref => $host_view->configManager->networkSystem);
        my $consolevNic = $networkSys->networkConfig->consoleVnic;
        foreach(@$consolevNic) {
                $VSWIF = $_->device;
                $PORTGROUP = $_->portgroup;
                $IP = $_->spec->ip->ipAddress;
                $NETMASK = $_->spec->ip->subnetMask;
                $MAC = $_->spec->mac;
                write;
        }
} else {
        print "This script is meant to be executed on classic ESX host and not ESXi, vswif interface do not exists\n";
}

Util::disconnect();
