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

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

$SIG{__DIE__} = sub{Util::disconnect()};

my %opts = (
        vihost => {
        type => "=s",
        help => "Name of the ESX/ESXi host to enable IPMI/iLO power setting",
        required => 1,
        },
        ipaddress => {
        type => "=s",
        help => "BMC IP Address",
        required => 1,
        },
        macaddress => {
        type => "=s",
        help => "BMC MAC Addresss",
        required => 1,
        },
        bmcusername => {
        type => "=s",
        help => "BMC Username",
        required => 1,
        },
);

# validate options, and connect to the server
Opts::add_options(%opts);

# validate options, and connect to the server
Opts::parse();
Opts::validate();
Util::connect();

my $vihost = Opts::get_option('vihost');
my $ipaddress = Opts::get_option('ipaddress');
my $macaddress = Opts::get_option('macaddress');
my $bmcusername = Opts::get_option('bmcusername');
my $bmcpassword = "";

my $host_view = Vim::find_entity_view(view_type => 'HostSystem', filter => {'name' => $vihost});

unless($host_view) {
        Util::disconnect();
        print "Error: Unable to locate host \"$vihost\"\n";
        exit 1;
}


print "\nPlease enter your BMC Password: ";
system("stty -echo");
chop($bmcpassword = <STDIN>);
print "\n";
system("stty echo");

eval {
        print "\nTrying to configure IPMI/iLO Settings for Power Management on $vihost ...\n";
        my $ipmiConfig = HostIpmiInfo->new(bmcIpAddress => $ipaddress, bmcMacAddress => $macaddress, login => $bmcusername, password => $bmcpassword);
        $host_view->UpdateIpmi(ipmiInfo => $ipmiConfig);
};
if($@) {
        print "Error: Unable to configure IPMI/iLO Settings: " . $@ . "\n";
}

Util::disconnect();
