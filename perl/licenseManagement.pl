#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://www.virtuallyghetto.com/2011/06/dreaded-faultrestrictedversionsummary.html

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
