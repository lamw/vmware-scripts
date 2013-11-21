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
