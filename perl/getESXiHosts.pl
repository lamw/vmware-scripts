#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;

my %opts = (
   hypervisorversion => {
      type => "=s",
      help => "Version of ESX(i) hosts to search for e.g. 5.0.0",
      required => 0,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $hypervisorversion = Opts::get_option('hypervisorversion');

my $vmhosts = Vim::find_entity_views(view_type => 'HostSystem', properties => ['name','runtime.connectionState','summary.config.product.version']);

foreach my $vmhost (@$vmhosts) {
	# list specific version of ESX(i) hosts in vCenter Server
	if($hypervisorversion) {
		if($vmhost->{'summary.config.product.version'} eq $hypervisorversion) {
			print $vmhost->{'name'} . "\t" . $vmhost->{'runtime.connectionState'}->val . "\n";
		}
	# list all ESX(i) hosts in vCenter Server
	} else {
		print $vmhost->{'name'} . "\t" . $vmhost->{'summary.config.product.version'} . "\t" . $vmhost->{'runtime.connectionState'}->val . "\n";
	}
}


Util::disconnect();

=head1 NAME

getESXiHosts.plgetESXiHosts.pl - Script to list all ESX(i) hosts in vCenter Server

=head1 Examples

=over 4

=item List all ESX(i) hosts

=item

./getESXiHosts.pl --server [VCENTER_SERVER] --username [USERNAME]

=item List specific version of ESX(i) hosts

=item

./getESXiHosts.pl --server [VCENTER_SERVER] --username [USERNAME] --hypervisorversion 5.0.0

=back

=head1 SUPPORT

vSphere 3.x,4.x and 5.x

=head1 AUTHORS

William Lam http://www.virtuallyghetto.com

=cut
