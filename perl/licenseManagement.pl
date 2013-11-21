#!/usr/bin/perl -w
# Copyright (c) 2009-2011 William Lam All rights reserved.

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
# 03/25/2011
# http://www.virtuallyghetto.com/
##################################################

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

$SIG{__DIE__} = sub{Util::disconnect();};

my %opts = (
   operation => {
      type => "=s",
      help => "[query|update]",
      required => 1,
   },
   license => {
      type => "=s",
      help => "License key (XXXXX-XXXXX-XXXXX-XXXXX-XXXXX)",
      required => 0,
   },
   vihost => {
      type => "=s",
      help => "Name of ESX(i) host to apply license if connecting to vCenter",
      required => 0,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $operation = Opts::get_option('operation');
my $license = Opts::get_option('license');
my $vihost = Opts::get_option('vihost');
my ($service_content,$host_type);

if($operation eq "query") {
	&queryHostType();
	&queryLicense();
}elsif($operation eq "update") {
	unless($license) {
		print "\"Update\" operation requires license variable to be defined!\n";
		Util::disconnect();
		exit 1;
	}
	&queryHostType();
        &updateLicense($license);
} else {
	print "Invalid Selection\n";
}

Util::disconnect();

sub queryHostType {
	$service_content = Vim::get_service_content();
	if($service_content->about->apiType eq 'VirtualCenter') {
		$host_type = "vc";
	} else {
		$host_type = "host";
	}
}

sub queryLicense {
	my $licMgr = Vim::get_view(mo_ref => $service_content->licenseManager);

	if($host_type eq "vc") {
		my $licAssignMgr =  Vim::get_view(mo_ref => $licMgr->licenseAssignmentManager);
		my $assignedLicenses = $licAssignMgr->QueryAssignedLicenses();
		
		foreach(@$assignedLicenses) {
			if($_->entityDisplayName) {
				print $_->entityDisplayName . "\t" . $_->assignedLicense->editionKey . "\t" . $_->assignedLicense->name . "\t" . $_->assignedLicense->licenseKey . "\n";
			}
		}
	} else {
		my $host = Vim::find_entity_view(view_type => 'HostSystem', properties => ['name']);
		my $licenses = $licMgr->licenses;
		
		print "License keys found for " . $host->{'name'} . "\n\n";
		foreach(@$licenses) {
			print $_->editionKey . "\t" . $_->name . "\t" . $_->licenseKey . "\n";
		}
	}
}

sub updateLicense {
	my ($lic) = @_;

	my $licMgr = Vim::get_view(mo_ref => $service_content->licenseManager);

	if($host_type eq "vc") {
		unless($vihost) {
			print "\"Update\" operation on vCenter requires vihost variable to be defined!\n";
	                Util::disconnect();
        	        exit 1;
		}

		my $vihost_view = Vim::find_entity_view(view_type => 'HostSystem', filter => { 'name' => $vihost}, properties => ['name']); 
		unless($vihost_view) {
			print "Unable to locate ESX(i) host: $vihost\n";
                        Util::disconnect();
                        exit 1;
		}
		
		my $vihost_id = $vihost_view->{'mo_ref'}->value;
		my $licAssignMgr =  Vim::get_view(mo_ref => $licMgr->licenseAssignmentManager);
		eval {
			print "Updating " . $vihost_view->{'name'} . " with license key " . $lic . "\n";
			$licAssignMgr->UpdateAssignedLicense(entity => $vihost_id, licenseKey => $lic);
		};
		if($@) {
			print "Error: " . $@ . "\n";
		}
	} else {
		eval {
			my $host = Vim::find_entity_view(view_type => 'HostSystem');

			print "Updating " . $host->name . " with license key " . $lic . "\n";
                        $licMgr->UpdateLicense(licenseKey => $lic);
                };
                if($@) {
                        print "Error: " . $@ . "\n";
                }
	}
}

=head1 NAME

licenseManager - Script to query and update license key for vCenter and/or ESX(i) hosts.

=head1 EXAMPLES

Query license on vCenter host:

	licenseManager --server [VCENTER_SERVER] --operation query

Query license on ESX(i) host:

	licenseManager --server [ESX(i)_SERVER] --operation query

Update license on vCenter host:

	licenseManager --server [VCENTER_SERVER] --operation update --license XXXXX-XXXXX-XXXXX-XXXXX-XXXXX --vihost [ESX(i)_SERVER_NAME]

Update license on ESX(i) host (Note: If ESX(i) host is connected to vCenter, this will fail. Connect to vCenter):

	licenseManager --server [ESX(i)_SERVER] --operation update --license XXXXX-XXXXX-XXXXX-XXXXX-XXXXX
