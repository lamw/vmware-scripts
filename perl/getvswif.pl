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
# 02/25/2009
# http://engineering.ucsb.edu/~duonglt/vmware
# http://communities.vmware.com/docs/DOC-9852

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
