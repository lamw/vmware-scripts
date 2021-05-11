#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://www.williamlam.com/2010/06/script-ipmiconfigpl.html

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
