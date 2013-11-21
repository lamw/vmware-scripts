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
# 01/25/2010
# http://www.virtuallyghetto.com/
# http://communities.vmware.com/docs/DOC-9852

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;
use VMware::VIExt;
use URI::URL;
use URI::Escape;
use LWP::Simple;
use POSIX qw/ceil mktime/;
use Net::SMTP;

#################
# EMAIL CONF
#################

my $SEND_MAIL = "no";
my $EMAIL_HOST = "mail.primp-industries.com";
my $EMAIL_DOMAIN = "primp-industries.com";
my $EMAIL_TO = 'William Lam <william@primp-industries.com>';
my $EMAIL_FROM = 'vMA <vMA@primp-industries.com>';

# define custom options for vm and target host
my %opts = (
   reportname=> {
      type => "=s",
      help => "Name of the report to email out",
      required => 0,
      default => 'vmwarevSphereSecurityHardeningReport.html',
   },
   cos => {
      type => "=s",
      help => "Run COS report",
      required => 0,
      default => 0,
   },
   host => {
      type => "=s",
      help => "Run Host report",
      required => 0,
      default => 0,
   },
   vcenter => {
      type => "=s",
      help => "Run vCenter report",
      required => 0,
      default => 0,
   },
   vnetwork => {
      type => "=s",
      help => "Run vNetwork report",
      required => 0,
      default => 0,
   },
   vm => {
      type => "=s",
      help => "Run VM report",
      required => 0,
      default => 0,
   },
   recommend_check_level => {
      type => "=s",
      help => "Recommendation check_level to check against [enterprise|dmz|sslf] for vSphere 4.x and [profile3,profile2,profile1] for vSphere 5.x",
      required => 1,
   },
   runall => {
      type => "=s",
      help => "Run all harden reports [COS|HOST|VCENTER|VNETWORK|VM]",
      required => 0,
      default => 1,
   },
   csv => {
      type => "=s",
      help => "Output report into CSV as well [yes|no] (Default: no)",
      required => 0,
      default => 'no',
   },
);

################################
# VERSION
################################
my $version = "5.1.0";
$Util::script_version = $version;

# read and validate command-line parameters 
Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();
my ($hosttype,$hostproduct,$hostapi) = &validateConnection('4.0.0','undef','both');

my %vms_all_adv_params = ();
my ($reportname,$cos,$host,$vcenter,$vnetwork,$vm,$runall,$recommend_check_level,$success,$csv);
my $report_name = "VMware vSphere Security Hardening Report $version";
my $hardenReportFolder = "vSphereHardenReport";
my %reportOutput = ("COS","","HOST","","VCENTER","","VNETWORK","","VM","");
my ($cos_success_count,$host_success_count,$vcenter_success_count,$vnetwork_success_count,$vm_success_count) = (0,0,0,0,0);
my ($cos_fail_count,$host_fail_count,$vcenter_fail_count,$vnetwork_fail_count,$vm_fail_count) = (0,0,0,0,0);
my ($cos_manual_count,$host_manual_count,$vcenter_manual_count,$vnetwork_manual_count,$vm_manual_count) = (0,0,0,0,0);
my ($cos_total,$host_total,$vcenter_total,$vnetwork_total,$vm_total) = (0,0,0,0,0);
my ($start_time,$end_time,$run_time);
my $debug = 0;
my ($hypervisor_ver,$vcenter_api);

$reportname = Opts::get_option('reportname');
$cos = Opts::get_option('cos');
$host = Opts::get_option('host');
$vcenter = Opts::get_option('vcenter');
$vnetwork = Opts::get_option('vnetwork');
$vm = Opts::get_option('vm');
$runall = Opts::get_option('runall');
$recommend_check_level = Opts::get_option('recommend_check_level');
$csv = Opts::get_option('csv');
my $csvOutput = "";
my $csvReportName = $reportname . ".csv";
my $level = uc($recommend_check_level);

#runall or subset of the checks
if($cos || $host || $vcenter || $vnetwork || $vm) {
	$runall = 0;
}

#verify check type
if($recommend_check_level ne "dmz" && $recommend_check_level ne "enterprise" && $recommend_check_level ne "sslf" && $recommend_check_level ne "profile1" && $recommend_check_level ne "profile2" && $recommend_check_level ne "profile3") {
	print "Invalid \"Recommend Check\" selection!\n";
	Util::disconnect();
	exit 1;
}

$report_name = $report_name . " ($level)";

#create temp working directory
&createBackupDirectory($hardenReportFolder);

&startReportCreation($hostapi);
if($hosttype eq 'VirtualCenter') {
	if($runall eq "1" || $vcenter eq "1") {
		my $servername = Opts::get_option('server');
		my $hostFolder = "$hardenReportFolder/" . $servername;
		&createBackupDirectory($hostFolder);
        	&vCenterReport($recommend_check_level,$hostFolder,$servername,$vcenter_api);
	}
	my $host_views = Vim::find_entity_views(view_type => 'HostSystem', filter => {'summary.runtime.connectionState' => 'connected'});
	foreach(sort {lc($a->name) cmp lc($b->name)} @$host_views) {
		my $hostFolder = "$hardenReportFolder/" . $_->name;
		&createBackupDirectory($hostFolder);
		&runHardenReportCheck($_,$hostFolder,$recommend_check_level);
	}		
} else {
	my $host_view = Vim::find_entity_view(view_type => 'HostSystem', filter => {'summary.runtime.connectionState' => 'connected'});
	my $hostFolder = "$hardenReportFolder/" . $host_view->name;
	&createBackupDirectory($hostFolder);
	&runHardenReportCheck($host_view,$hostFolder,$recommend_check_level);
}
&printReport($hosttype);
&endReportCreation();

Util::disconnect();

if($SEND_MAIL eq "yes") {
        &sendMail();
}

#clean up
`/bin/rm -rf $hardenReportFolder`;

########################
# HELPER FUNCTIONS
########################

sub runHardenReportCheck {
	my ($host_view,$folder,$check_level) = @_;
	my $hostname = $host_view->name;
	my $host_username = Opts::get_option("username");
        my $host_password = Opts::get_option("password");

	my $product = $host_view->config->product->productLineId;
	$hypervisor_ver = $host_view->config->product->version;

	if($product eq 'esx') {
		if($runall eq "1" || $cos eq "1") {
			&COSReport($host_view,$product,$folder,$hostname,$host_username,$host_password,$check_level,$hypervisor_ver);
		}
	}
	
	if($runall eq "1" || $host eq "1") {
		&HOSTReport($host_view,$product,$folder,$hostname,$host_username,$host_password,$check_level,$hypervisor_ver);
	}

	if($runall eq "1" || $vnetwork eq "1") {
		&vNetworkReport($host_view,$product,$folder,$hostname,$host_username,$host_password,$check_level,$hypervisor_ver);
	}

	if($runall eq "1" || $vm eq "1") {
		&VMReport($host_view,$product,$folder,$hostname,$host_username,$host_password,$check_level,$hypervisor_ver);	
	}
}

sub vCenterReport {
	my ($req_check_level,$folder,$hostname) = @_;

	my ($success,$code,$desc,$resolution,$check_level,@supportedApiVer,@supportedCheckLevel);
	$vcenter_api = Vim::get_service_content()->about->version;

	my $service = Vim::get_vim_service();
        my $service_url = URI::URL->new($service->{vim_soap}->{url});
        $service_url =~ s/sdk//g;
        my $user_agent = $service->{vim_soap}->{user_agent};

	#VSH01
	$success = 2;
	$desc = "Maintain supported operating system database and hardware for vCenter";
	$resolution = "Please refer to vCenter doc for further details";
	if($vcenter_api eq "5.0.0" || $vcenter_api eq "5.1.0") {
		$code = "use-supported-system";
	} else {
		$code = "VSH01";
	}
	@supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
	@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
	if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
                &log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#VSH02
	$success = 2;
	$desc = "Keep vCenter Server system properly patched";
	$resolution = "Stay up-to-date on patches for Windows Server";
	if($vcenter_api eq "5.0.0" || $vcenter_api eq "5.1.0") {
                $code = "apply-os-patches";
	} else {
		$code = "VSH02";
	}
	@supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        @supportedCheckLevel = qw(enterprise profile1 profile3);
	if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
                &log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
        }
	
	#VSH03
	$success = 2;
        $desc = "Provide standard Windows system protection on the vCenter Server host";
        $resolution = "Provide Windows system protection";
	if($vcenter_api eq "5.0.0" || $vcenter_api eq "5.1.0") {
		$code = "secure-vcenter-os";
        } else {
		$code = "VSH03";
	}
	@supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        @supportedCheckLevel = qw(enterprise profile1 profile3);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
                &log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#VSH04
        $success = 2;
	$desc = "Avoid unneeded user login to vCenter Server system";
	$resolution = "Self explantory";
	if($vcenter_api eq "5.0.0" || $vcenter_api eq "5.1.0") {
                $code = "limit-user-login";
        } else {
		$code = "VSH04";
	}
	@supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        @supportedCheckLevel = qw(enterprise profile1 profile3);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
                &log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#VSH05
        $success = 2;
	$desc = "Install vCenter Server using a Service Account instead of a built-in Windows account";
	$resolution = "Setup Service Account to run vCenter service";
	if($vcenter_api eq "5.0.0" || $vcenter_api eq "5.1.0") {
                $code = "install-with-service-account";
	} else {
		$code = "VSH05";
	}
	@supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        @supportedCheckLevel = qw(dmz profile1 profile2);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
               	&log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
       	}

	#VSH06
	$success = 2;
	$desc = "Restrict usage of vSphere administrator privilege";
	$resolution = "Please refer to vCenter doc for further details";
	if($vcenter_api eq "5.0.0" || $vcenter_api eq "5.1.0") {
                $code = "restrict-admin-privilege";
        } else {
		$code = "VSH06";
	}
	@supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        @supportedCheckLevel = qw(enterprise dmz profile3);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
                &log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
	}

	$success = 2;
	$desc = "Secure the vSphere Administrator role and assign it to specific users";
	$resolution = "Please refer to vCenter doc for further details";
	$code = "restrict-admin-role";
	@supportedApiVer = qw(5.0.0 5.1.0);
        @supportedCheckLevel = qw(profile1 profile3);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
                &log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	$success = 2;
        $desc = "Restrict unauthorized vSphere users from being able to execute commands within the guest virtual machine";
	$resolution = "Please refer to vCenter doc for further details";
        $code = "restrict-guest-control";
	@supportedApiVer = qw(5.0.0 5.1.0);
        @supportedCheckLevel = qw(profile1 profile2);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
                &log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	$success = 2;
        $desc = "restrict-Linux-clients";
        $resolution = "Please refer to vCenter doc for further details";
        $code = "restrict-Linux-clients";
        @supportedApiVer = qw(5.1.0);
        @supportedCheckLevel = qw(profile1 profile2);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
                &log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#VSH07
        $success = 2;
        $desc = "Check for privilege re-assignment after vCenter Server restarts";
	$resolution = "Please refer to vCenter doc for further details & <a href=\"http://kb.vmware.com/kb/1021804\">http://kb.vmware.com/kb/1021804</a>";
	if($vcenter_api eq "5.0.0" || $vcenter_api eq "5.1.0") {
                $code = "check-privilege-reassignment";
        } else {
		$code = "VSH07";
	}
	@supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1. 5.1.0);
        @supportedCheckLevel = qw(dmz profile1 profile2);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
               	&log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
	}

	$success = 2;
	$code = "monitor-admin-assignment";
	$desc = "Monitor that vCenter Server administrative users have the correct Roles assigned";
	$resolution = "Please refer to vCenter doc for further details";
	@supportedApiVer = qw(5.0.0 5.1.0);
        @supportedCheckLevel = qw(profile1 profile2);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
                &log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	$success = 2;
        $code = "remove-revoked-certificates";
        $desc = "Remove revoked certificates from vCenter Server";
        $resolution = "Please refer to vCenter doc for further details";
        @supportedApiVer = qw(5.1.0);
        @supportedCheckLevel = qw(profile1 profile2);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
                &log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#VSH10
        $success = 2;
	if($vcenter_api eq "5.0.0" || $vcenter_api eq "5.1.0") {
		$code = "remove-failed-install-logs";
	} else {
        	$code = "VSH10";
	}
        $desc = "Clean up log files after failed installations of vCenter Server";
	$resolution = "Please refer to vCenter doc for further details & <a href=\"http://kb.vmware.com/kb/1021804\">http://kb.vmware.com/kb/1021804</a>";
	@supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        @supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
                &log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
        }
	
	#VSC01
	$success = 1;
	$desc = "Do not use default self-signed certificates";
	if($vcenter_api eq "5.0.0" || $vcenter_api eq "5.1.0") {
                $code = "no-self-signed-certs";
	} else {
		$code = "VSC01";
	}
	@supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        @supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
		my $url = $service_url;
		my $request;
		eval {
			$request = HTTP::Request->new("GET",$url);
			my $response = $user_agent->request($request);
			if($response) {
				my $ssl_issuer = $response->header("client-ssl-cert-issuer");
				if($ssl_issuer =~ m/VMware Installer/) {
					$success = 0;
                                	$resolution = "VMware default SSL cert should not be used";
				}
			} else {
				$success = 2;
                        	$resolution = "Unable to verify SSL cert";
			}
		};
		if($@) {
			$success = 0;
			print "Failed to verify SSL cert - $@\n";
			$resolution = "Failed to verify SSL cert";
		}
		if($success eq 1) {
			$resolution = "N/A";
		}
		&log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
	}

	# download SSL cert from remote host
        my $download_ssl_vc = `echo '' | openssl s_client -connect $hostname:443 2> $folder/tmp 1> $folder/ssl_cert`;

	$success = 1;
        $code = "check-vc-ssl-cert-expiry";
        $desc = "Verify SSL Certificate expiry";
        @supportedCheckLevel = qw(profile1 profile2 profile3);
        @supportedApiVer = qw(5.0.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
                my $openssl_results = `openssl x509 -noout -in "$folder/ssl_cert" -enddate | awk -F 'notAfter=' '{print \$2}' | awk '{print \$1, \$2, \$4}'`;
                if($openssl_results) {
                        my $todays_date = &giveMeDate('YMD');
                        my $ssl_date = &getSSLDate($openssl_results);
                        my $diff = &days_between($todays_date,$ssl_date);
                        if($diff <= 10) {
                                $success = 0;
                                $resolution = "SSL Certificate expiration in $diff days!";
                                &log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
                        } else {
                                $success = 1;
                                $resolution = "SSL Certificate has not expired";
                                &log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
                        }
                } else {
                        $success = 2;
                        $resolution = "Could not verify SSL Certificate expiry";
                        &log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
                }
        }
	
	#VSC02
        $success = 2;
        $desc = "Monitor access to SSL certificates";
	$resolution = "Please refer to vCenter doc for further details";
	if($vcenter_api eq "5.0.0" || $vcenter_api eq "5.1.0") {
                $code = "monitor-certificate-access";
        } else {
		$code = "VSC02";
	}
	@supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        @supportedCheckLevel = qw(dmz profile1 profile2);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
		&log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
	}

	$success = 2;
        $desc = "Remove expired certificates from vCenter Server.";
        $resolution = "Please refer to vCenter doc for further details";
	$code = "remove-expired-certificates";
        @supportedApiVer = qw(5.1.0);
        @supportedCheckLevel = qw(profile1 profile2 profile3);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
                &log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#VSC03
        $success = 2;
	$desc = "Restrict access to SSL certificates";
	$resolution = "Please refer to vCenter doc for further details";
	if($vcenter_api eq "5.0.0" || $vcenter_api eq "5.1.0") {
                $code = "restrict-certificate-access";
	} else {
		$code = "VSC03";
	}
	@supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        @supportedCheckLevel = qw(sslf profile1);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
		&log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);	
	}

	#VSC04
        $success = 2;
        $desc = "Always verify SSL certificates";
	$resolution = "Please refer to vCenter doc for further details";
	if($vcenter_api eq "5.0.0" || $vcenter_api eq "5.1.0") {
                $code = "verify-ssl-certificates";
	} else {
		$code = "VSC04";
	}
	@supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        @supportedCheckLevel = qw(dmz profile1 profile2 profile3);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
                &log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	$success = 2;
	$desc = "Set a timeout for thick-client login without activity";
	$resolution = "Set inactivity timeout for the vSphere Client (thick client)";
	$code = "thick-client-timeout";
	@supportedApiVer = qw(5.0.0 5.1.0);
	@supportedCheckLevel = qw(profile1 profile2 profile3);
	if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
                &log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#VSC05
        $success = 2;
        $desc = "Restrict network access to vCenter";
	$resolution = "Use a local firewall or Windows systems to protect vCenter";
	if($vcenter_api eq "5.0.0" || $vcenter_api eq "5.1.0") {
                $code = "restrict-network-access";
        } else {
		$code = "VSC05";
	}
	@supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        @supportedCheckLevel = qw(dmz profile1 profile2);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
                &log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	$success = 2;
        $desc = "Use least privileges for the vCenter Server database user";
        $resolution = "Please refer to vCenter doc for further details";
        $code = "restrict-vcs-db-user";
        @supportedApiVer = qw(5.1.0);
        @supportedCheckLevel = qw(profile1 profile2 profile3);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
                &log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#VSC06
        $success = 2;
        $desc = "Block access to ports not being used by vCenter";	
	$resolution = "Verify ports using <a href=\"http://kb.vmware.com/kb/1012382\">http://kb.vmware.com/kb/1012382</a>";
	if($vcenter_api eq "5.0.0" || $vcenter_api eq "5.1.0") {
                $code = "block-unused-ports";
        } else {
		$code = "VSC06";
	}
	@supportedCheckLevel = qw(dmz profile1 profile2);
	@supportedApiVer = qw(4.0.0 4.1.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
                &log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	$success = 2;
        $desc = "Disable datastore Web browser";
        $resolution = "Add &#60;enableHttpDatastoreAccess&#62;false&#60;/enableHttpDatastoreAccess&#62 to vpxd.cfg";
        $code = "disable-datastore-web";
        @supportedApiVer = qw(5.1.0);
        @supportedCheckLevel = qw(profile1);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
                &log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	$success = 2;
        $desc = "Restrict datastore browser";
        $resolution = "Please refer to vCenter doc for further details ";
        $code = "restrict-datastore-web";
        @supportedApiVer = qw(5.1.0);
        @supportedCheckLevel = qw(profile2 profile3);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
                &log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#VSC07
        $success = 1;
	if($vcenter_api eq "5.0.0" || $vcenter_api eq "5.1.0") {
                $code = "disable-mob";
	} else {
        	$code = "VSC07";
	}
	$desc = "Disable Managed Object Browser";
	@supportedCheckLevel = qw(dmz profile1 profile2);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
		my $url = $service_url;
		$url =~ s/\/webService//g;
		$url = $url . "mob";
                my $request;
                eval {
                        $request = HTTP::Request->new("GET",$url);
                        my $response = $user_agent->request($request);
			if($response) {
                        	if($response->code ne '404') {
					$success = 0;
					$resolution = "Disable MOB by adding &#60;enableDebugBrowse&#62;false&#60;enableDebugBrowse/&#62; to vpxd.cfg";
				}
                        } else {
                                $success = 2;
                                $resolution = "Unable to verify MOB URL";
                        }
                };
                if($@) {
                        $success = 0;
			print "Failed to verify MOB URL on vCenter - $@\n";
                        $resolution = "Failed to verify MOB URL on vCenter";
                }
		if($success eq 1) {
			$resolution = "N/A";
		}
		&log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#VSC08
        $success = 1;
        $code = "VSC08";
        $desc = "Disable Web Access";
	@supportedCheckLevel = qw(sslf);
        @supportedApiVer = qw(4.0.0 4.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
		my $url = $service_url;
                $url =~ s/\/webService//g;
                $url = $url . "ui";
                my $request;
                eval {
                        $request = HTTP::Request->new("GET",$url);
                        my $response = $user_agent->request($request);
                        if($response) {
                                my $title = $response->header("title");
                                if($title =~ m/vSphere Web Access/) {
                                        $success = 0;
					$resolution = "Disable Web Access - Please refer to <a href=\"http://kb.vmware.com/kb/1009420\">http://kb.vmware.com/kb/1009420</a>";
                                }
                        } else {
                                $success = 2;
                                $resolution = "Unable to verify Web Access URL";
                        }
                };
                if($@) {
                        $success = 0;
			print "Failed to verify Web Acceess URL on vCenter - $@\n";
                        $resolution = "Failed to verify Web Acceess URL on vCenter";
                }
                if($success eq 1) {
                        $resolution = "N/A";
                }
                &log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#VSC09
        $success = 2;
	if($vcenter_api eq "5.0.0") {
        	$code = "disable-datastore-browser";
	} else {
		$code = "VSC09";
	}
        $desc = "Disable Datastore Browser";
	$resolution = "Disable Datastore Browser by adding &#60;enableHttpDatastoreAccess&#62;false&#60;enableHttpDatastoreAccess/&#62; to vpxd.cfg";
	@supportedCheckLevel = qw(sslf profile1);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
		&log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
	}
	
	#VSD01
        $success = 2;
	if($vcenter_api eq "5.0.0") {
                $code = "restrict-vc-db-user";
	} else {
		$code = "VSD01";
	}
        $desc = "Use least privileges for the vCenter Database";
	$resolution = "Please refer to vCenter doc for further details";
	@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
                &log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	$success = 2;
        $code = "restrict-vum-db-user";
	$desc = "Use least privileges for the Update Manager database user";
	@supportedCheckLevel = qw(profile1 profile2 profile3);
        @supportedApiVer = qw(5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
                &log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	$success = 2;
        $code = "limit-vum-users";
        $desc = "Limit user login to Update Manager system";
        @supportedCheckLevel = qw(profile1 profile2 profile3);
        @supportedApiVer = qw(5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
                &log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

        $success = 2;
        $code = "audit-vum-login";
        $desc = "Audit user login to Update Manager system";
        @supportedCheckLevel = qw(profile1 profile2 profile3);
        @supportedApiVer = qw(5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
                &log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#VCL01
	$success = 2;
	$desc = "Restrict the use of Linux.based Clients";
	$resolution = "Please refer to vCenter doc for further details";
	if($vcenter_api eq "5.0.0") {
		$code = "restrict-linux-clients";
	} else {
		$code = "VCL01";
	}
	@supportedCheckLevel = qw(dmz profile1 profile2);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
               	&log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
	}

	#VCL02
        $success = 2;
        $desc = "Verify the Integrity of vSphere Client";
	$resolution = "Verify plugin extensions under Plugins->Managed Plugins on the Installed Plugins tab";
	if($vcenter_api eq "5.0.0" || $vcenter_api eq "5.1.0") {
                $code = "verify-client-plugins";
	} else {
		$code = "VCL02";
	}
	@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
                &log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
        }
 
	#VUM01
	$success = 1;
        $code = "VUM01";
	$desc = "Install Update Manager on a different machine from vCenter";		
	$resolution = "Isolate VUM from vCenter";
	@supportedCheckLevel = qw(enterprise);
        @supportedApiVer = qw(4.0.0 4.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
		my $extMgr = Vim::get_view(mo_ref => Vim::get_service_content()->extensionManager);
		my $vpxSetting = Vim::get_view(mo_ref => Vim::get_service_content()->setting);

		my $vpxSettings = $vpxSetting->setting;
		my $vCenterIP;
		foreach(@$vpxSettings) {
			if($_->key eq "VirtualCenter.VimApiUrl") {
				if(defined($_->value)) {
					my $vCenterHostname = $_->value;
					$vCenterHostname =~ m|(\w+)://([^/:]+)(:\d+)?/(.*)|;
					my @vCenterInfo = gethostbyname($2);
					my @ip = unpack("C4",$vCenterInfo[4]);
                                	$vCenterIP = join(".",@ip);
				} else {
					$vCenterIP = "";
				}
				last;
			}
		}

		my $extensions = $extMgr->extensionList;
		foreach(@$extensions) {
			if($_->key eq "com.vmware.vcIntegrity") {
				if($_->server) {
					my $serverExt = $_->server;
					foreach(@$serverExt) {
						if($_->type eq "SOAP") {
							my $vumURL = $_->url;
							$vumURL =~ m|(\w+)://([^/:]+)(:\d+)?/(.*)|;
							my $vumIP = $2;

							if($vumIP eq $vCenterIP) {
								$success = 0;
								$resolution = "VUM should not be installed on the same server as vCenter";
							}
							last;
						}
					}
				}
			}	
		}

                if($success eq 1) {
                        $resolution = "N/A";
                }
                &log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
        }


	#VUM02
        $success = 2;
	if($vcenter_api eq "5.0.0" || $vcenter_api eq "5.1.0") {
		$code = "patch-vum-os";
	} else {
		$code = "VUM02";
	}
	$desc = "Keep Update Manager system properly patched";
	$resolution = "Keep VUM patched";
	@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
                &log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#VUM03
	$success = 2;
	if($vcenter_api eq "5.0.0" || $vcenter_api eq "5.1.0") {
                $code = "secure-vum-os";
        } else {
		$code = "VUM03";
	}
	$desc = "Provide standard Windows system protection on the Update Manager host";
	$resolution = "Provide Windows system protection";
	@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
                &log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#VUM04
        $success = 2;
	if($vcenter_api eq "5.0.0") {
                $code = "limit-vum-server-user-login";
        } else {
        	$code = "VUM04";
	}
	$desc = "Avoid user login to Update Manager system";
	$resolution = "Self explanatory";
	@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
                &log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#VUM05
	$success = 2;
	if($vcenter_api eq "5.0.0" || $vcenter_api eq "5.1.0") {
                $code = "no-vum-self-management";
        } else {
		$code = "VUM05";
	}
	$desc = "Do not configure Update Manager to manage its own VM or its vCenter Server's VM";
	$resolution = "Self explanatory";
	@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
                &log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
        }
		
	#VUM06
        $success = 2;
	if($vcenter_api eq "5.0.0" || $vcenter_api eq "5.1.0") {
                $code = "no-vum-self-signed-certs";
        } else {
	        $code = "VUM06";
	}
        $desc = "Do not use default self-signed certificates";
        $resolution = "Please refer to vCenter doc for further details & <a href=\"http://kb.vmware.com/kb/1023011\">http://kb.vmware.com/kb/1023011</a>";
	@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
                &log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#VUM10
	$success = 2;
	if($vcenter_api eq "5.0.0" || $vcenter_api eq "5.1.0") {
                $code = "isolate-vum-airgap";
        } else {
        	$code = "VUM10";
	}
	$desc = "Limit the connectivity between Update Manager and public patch repositories";	
	$resolution = "Please refer to the vCenter doc for further details";
	@supportedCheckLevel = qw(enterprise dmz sslf profile1);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
		&log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
	}

	$success = 2;
	$code = "isolate-vum-proxy";
	$desc = "Limit the connectivity between Update Manager and public patch repositories";
	$resolution = "Please refer to the vCenter doc for further details";
	@supportedCheckLevel = qw(profile3);
	@supportedApiVer = qw(5.0.0 5.1.0);
	if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
                &log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	$success = 2;
        $code = "isolate-vum-webserver";
	$desc = "Limit the connectivity between Update Manager and public patch repositories";
	$resolution = "Please refer to the vCenter doc for further details";
        @supportedCheckLevel = qw(profile2);
        @supportedApiVer = qw(5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
                &log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	$success = 2;
        $code = "secure-vco-file-access";
        $desc = "Restrict read access to VCO files with authentication data to administrators";
        $resolution = "Please refer to the vCenter doc for further details";
        @supportedCheckLevel = qw(profile1 profile2 profile3);
        @supportedApiVer = qw(5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$vcenter_api)) {
                &log("VCENTER",$hostname,$code,$desc,$success,"N/A",$resolution);
        }
}

sub vNetworkReport {
	my ($host_view,$product,$folder,$hostname,$host_username,$host_password,$check_level,$host_api) = @_;

	my ($code,$desc,$resolution,$req_check_level,@supportedApiVer,@supportedCheckLevel);
	my $networks = Vim::get_views(mo_ref_array => $host_view->network);
	my $networkSys = Vim::get_view(mo_ref => $host_view->configManager->networkSystem);
	my $vSwitches = $networkSys->networkInfo->vswitch;	

	#NAR01
        $success = 2;
	$resolution = "Please refer to the vNetwork Doc for further details";
	if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
		$code = "isolate-mgmt-network-vlan";
	} else {
		$code = "NAR01";
	}
	$desc = "Ensure that vSphere management traffic is on a restricted network";
	@supportedCheckLevel = qw(enterprise sslf dmz profile2 profile3);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
		&log("VNETWORK",$hostname,$code,$desc,$success,"N/A",$resolution);
	}			

	$success = 2;
	$desc = "Ensure that vSphere management traffic is on a restricted network";
	$resolution = "Please refer to the vNetwork Doc for further details";
	$code = "isolate-mgmt-network-airgap";
	@supportedCheckLevel = qw(profile1);
        @supportedApiVer = qw(5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("VNETWORK",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#NAR02
        $success = 2;
	$desc = "Ensure VMotion Traffic is isolated";
        $resolution = "Please refer to the vNetwork Doc for further details";
	if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
                $code = "isolate-vmotion-network-vlan";
	} else {
		$code = "NAR02";
	}
	@supportedCheckLevel = qw(enterprise sslf dmz profile2 profile3);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
        	&log("VNETWORK",$hostname,$code,$desc,$success,"N/A",$resolution);
	}

	$success = 2;
	$desc = "Ensure VMotion Traffic is isolated";
        $resolution = "Please refer to the vNetwork Doc for further details";
        $code = "isolate-vmotion-network-airgap";
        @supportedCheckLevel = qw(profile1);
        @supportedApiVer = qw(5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("VNETWORK",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#NAR03
        $success = 2;
	$desc = "Ensure IP Based Storage Traffic is isolated";
        $resolution = "Please refer to the vNetwork Doc for further details";
	if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
                $code = "isolate-storage-network-airgap";
        } else {
		$code = "NAR03";
	}
	@supportedCheckLevel = qw(enterprise sslf dmz profile2 profile3);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
        	&log("VNETWORK",$hostname,$code,$desc,$success,"N/A",$resolution);
	}

	#NAR02
        $success = 2;
        $desc = "Ensure that IP-based storage traffic is isolated";
        $resolution = "Please refer to the vNetwork Doc for further details";
        if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
                $code = "isolate-storage-network-vlan";
        } else {
                $code = "NAR02";
        }
        @supportedCheckLevel = qw(enterprise sslf dmz profile2 profile3);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("VNETWORK",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	$success = 2;
        $desc = "Ensure IP Based Storage Traffic is isolated";
        $resolution = "Please refer to the vNetwork Doc for further details";
        $code = "isolate-storage-network-airgap";
        @supportedCheckLevel = qw(profile1);
        @supportedApiVer = qw(5.0.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("VNETWORK",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#TODO
	$success = 2;
	$desc = "Ensure that only authorized administrators have access to virtual networking components";
	$resolution = "Please refer to the vNetwork Doc for further details";
	$code = "limit-administrator-scope";
	@supportedCheckLevel = qw(profile1 profile2 profile3);
        @supportedApiVer = qw(5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("VNETWORK",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#NAR04
        $success = 2;
	$desc = "Strictly control access to Management network";
        $resolution = "Please refer to the vNetwork Doc for further details";
	if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
                $code = "restrict-mgmt-network-access-gateway";
	} else {
		$code = "NAR04";
	}
	@supportedCheckLevel = qw(enterprise sslf dmz profile1);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
	       	&log("VNETWORK",$hostname,$code,$desc,$success,"N/A",$resolution);
	}

	$success = 2;
	$desc = "Strictly control access to Management network";
        $resolution = "Please refer to the vNetwork Doc for further details";
	$code = "restrict-mgmt-network-access-jumpbox";
	@supportedCheckLevel = qw(enterprise sslf dmz profile2 profile3);
        @supportedApiVer = qw(5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("VNETWORK",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

        $success = 2;
        $desc = "Ensure that physical switch ports are configured with Portfast if spanning tree is enabled";
        $resolution = "Please refer to the vNetwork Doc for further details";
        $code = "enable-portfast";
        @supportedCheckLevel = qw(profile1 profile2 profile3);
        @supportedApiVer = qw(5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("VNETWORK",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#NCN02
	$success = 1;
	$desc = "Ensure that there are no unused ports on a Distributed vSwitch Port Group";
	if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
		$code = "no-unused-dvports";
	} else {
		$code = "NCN02";
	}	
	@supportedCheckLevel = qw(dmz profile1 profile2 profile3);
       	@supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
        	my $dvsMgr = Vim::get_view(mo_ref => Vim::get_service_content()->dvSwitchManager);
                my $dvs_targets = $dvsMgr->QueryDvsConfigTarget(host => $host_view);
                my $dvs = $dvs_targets->distributedVirtualSwitch;

                foreach(@$dvs) {
                	my $dvSwitch = Vim::get_view(mo_ref => $_->distributedVirtualSwitch);
                        my $dvPortgroups = Vim::get_views(mo_ref_array => $dvSwitch->portgroup);
                        foreach(@$dvPortgroups) {
                        	my $numPorts = $_->config->numPorts;
                                my $count = Vim::get_views(mo_ref_array => $_->vm);
                                if($numPorts ne @$count) {
                                	$success = 0;
                                        my $notUsed = ($numPorts - @$count);
                                        $resolution = "Portgroup: " . $_->name . " has total of $numPorts ports with $notUsed not being used";
                                }
                        }
                }
                if($success eq 1) {
                	$resolution = "N/A";
                }
                &log("VNETWORK",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	$success = 1;
	$code = "disable-dvportgroup-autoexpand";
	$desc = "Verify that the autoexpand option for VDS dvPortgroups is disabled";
	@supportedCheckLevel = qw(profile1 profile2);
	@supportedApiVer = qw(5.0.0 5.1.0);
	my $dvPortgroupList;
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
		my $dvSwitches = Vim::find_entity_views(view_type => 'DistributedVirtualSwitch', properties => ['name','portgroup']);
		foreach(@$dvSwitches) {
			my $dvSwitchName = $_->{'name'};
			my $dvPortgroups = Vim::get_views(mo_ref_array => $_->{'portgroup'}, properties => ['name','config']);
			foreach(@$dvPortgroups) {
				my $dvPortgroupName = $_->{'name'};
				if(defined($_->config->autoExpand)) {
					if($_->config->autoExpand) {
						$success = 0;
						$dvPortgroupList .= " " . $dvPortgroupName;
					}
				}
			}
		}
		if($success) {
			$resolution = "N/A";
		} else {
			$resolution = "The following dvPortgroup w/autoExpand " . $dvPortgroupList;
		}	
		&log("VNETWORK",$hostname,$code,$desc,$success,"N/A",$resolution);
	}

	my ($macSuccess,$forgeSuccess,$promSuccess) = (1,1,1);
        @supportedCheckLevel = qw(profile1 profile2 profile3);
        @supportedApiVer = qw(5.0.0 5.1.0);
	my (@dvpgMacChange,@dvpgForgedTransmit,@dvpgProm) = ();
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                my $dvSwitches = Vim::find_entity_views(view_type => 'DistributedVirtualSwitch', properties => ['name','portgroup']);
                foreach(@$dvSwitches) {
                        my $dvSwitchName = $_->{'name'};
                        my $dvPortgroups = Vim::get_views(mo_ref_array => $_->{'portgroup'}, properties => ['name','config','tag']);
                        foreach(@$dvPortgroups) {
                                my $dvPortgroupName = $_->{'name'};
				if($_->{'config'}->defaultPortConfig->securityPolicy->macChanges->value && !defined($_->{'tag'})) {
					$macSuccess = 0;
					push @dvpgMacChange,$dvPortgroupName;
				}

				if($_->{'config'}->defaultPortConfig->securityPolicy->forgedTransmits->value && !defined($_->{'tag'})) {
                                        $forgeSuccess = 0;
                                        push @dvpgForgedTransmit,$dvPortgroupName;
                                }

				if($_->{'config'}->defaultPortConfig->securityPolicy->allowPromiscuous->value && !defined($_->{'tag'})) {
                                        $promSuccess = 0;
                                        push @dvpgProm,$dvPortgroupName;
                                }				
			}
			$code = "reject-mac-change-dvportgroup";
			$desc = "Ensure the \"Mac Address Change\" policy is set to Reject";
			if(scalar(@dvpgMacChange) gt 0) {
				$resolution = "dvSwitch: " . $dvSwitchName . " has Mac Address Change enabled for " . join(' ',@dvpgMacChange);
			} else {
				$resolution = "N/A";
			}
			&log("VNETWORK",$hostname,$code,$desc,$macSuccess,"N/A",$resolution);

			$code = "reject-forged-transmit-dvportgroup";
			$desc = "Ensure the \"Forged Transmits\" policy is set to Reject";
			if(scalar(@dvpgForgedTransmit) gt 0) {
				$resolution = "dvSwitch: " . $dvSwitchName . " has Forged Transmits enabled for " . join(' ',@dvpgForgedTransmit);
			} else {
                                $resolution = "N/A";
                        }
                        &log("VNETWORK",$hostname,$code,$desc,$forgeSuccess,"N/A",$resolution);

			$code = "reject-promiscuous-mode-dvportgroup";
			$desc = "Ensure the \"Promiscuous Mode\" policy is set to Reject";
			if(scalar(@dvpgProm) gt 0) {
				$resolution = "dvSwitch: " . $dvSwitchName . " has Promiscuous Mode enabled for " . join(' ',@dvpgProm);
			} else {
                                $resolution = "N/A";
                        }
                        &log("VNETWORK",$hostname,$code,$desc,$promSuccess,"N/A",$resolution);
		}
        }

	#NCN03,NCN04,NCN05
	$success = 1;
	@supportedCheckLevel = qw(dmz profile1 profile2 profile3);
	@supportedApiVer = qw(4.0.0 4.1.0 5.0.0);
	if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
		foreach(@$vSwitches) {
			my $vSwitch_name = $_->name;
			if($_->spec->policy->security) {
				if($_->spec->policy->security->macChanges) {
					$success = 0;
					if($host_api eq "5.0.0") {
						$code = "reject-mac-changes";
					} else {
						$code = "NCN03";
					}
					$desc = "Ensure the \"MAC Address Change\" policy is set to Reject";
					$resolution = "vSwitch: $vSwitch_name should not have \"MAC Adddress Change\" policy set to accept";
					&log("VNETWORK",$hostname,$code,$desc,$success,"N/A",$resolution);
				}
				if($_->spec->policy->security->forgedTransmits) {
					$success = 0;
					if($host_api eq "5.0.0") {
                                                $code = "reject-forged-transmit";
					} else {
                                        	$code = "NCN04";
					}
					$desc = "Ensure the \"Forged Transmits\" policy is set to Reject";
					$resolution = "vSwitch: $vSwitch_name should not have \"Forged Transmits\" policy set to accept";
					&log("VNETWORK",$hostname,$code,$desc,$success,"N/A",$resolution);
				}
				if($_->spec->policy->security->allowPromiscuous) {
					$success = 0;
					if($host_api eq "5.0.0") {
                                                $code = "reject-promiscuous-mode";
					} else {
                                        	$code = "NCN05";
					}
                                        $desc = "Ensure the \"Promiscuous Mode\" policy is set to Reject";
					$resolution = "vSwitch: $vSwitch_name should not have \"Promiscuous Mode\" policy set to accept";
					&log("VNETWORK",$hostname,$code,$desc,$success,"N/A",$resolution);
				}
			}
		}
		if($success eq 1) {
                        $resolution = "N/A";
                        &log("VNETWORK",$hostname,$code,$desc,$success,"N/A",$resolution);
                }
	}

	#NCN06
        $success = 2;
	$desc = "Ensure that port groups are not configured to value of the native VLAN";
	$resolution = "Please refer to vNetwork doc for further details";
	if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
		$code = "no-native-vlan-1";
	} else {
		$code = "NCN06";
	}
	@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
        	&log("VNETWORK",$hostname,$code,$desc,$success,"N/A",$resolution);
	}

	#NCN07
        $success = 2;
        $desc = "Ensure that port groups are not configured to VLAN 4095 except for Virtual Guest Tagging (VGT)";
        $resolution = "VLAN ID setting on all port groups should not be set to 4095 unless VGT is required";
	if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
                $code = "no-vgt-vlan-4095";
        } else {
		$code = "NCN07";
	}
	@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("VNETWORK",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#NCN08
        $success = 2;
        $desc = "Ensure that port groups are not configured to VLAN values reserved by upstream physical switches";
        $resolution = "VLAN ID setting on all port groups should not be set to reserved values of the physical switch";
	if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
                $code = "no-reserved-vlans";
        } else {
		$code = "NCN08";
	}
	@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("VNETWORK",$hostname,$code,$desc,$success,"N/A",$resolution);
        }
		
	#NCN10
        $success = 2;
	$desc = "Ensure that port groups are configured with a clear network label";
	$resolution = "Clearly label your portgroups along with identifer to specify functionality";
	if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
                $code = "label-portgroups";
        } else {
		$code = "NCN10";
	}
	@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("VNETWORK",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#NCN11
	$success = 2;
	$desc = "Ensure that all vSwitches have a clear network label";
	$resolution = "Clearly label your vSwitches";
	if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
                $code = "label-vswitches";
        } else {
		$code = "NCN11";
	}
	@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("VNETWORK",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	$success = 2;
        $desc = "Ensure that all vdSwitch VLAN ID's are fully documented";
	$resolution = "Clearly label your dvPortgroups";
	$code = "document-vlans-vds";
	@supportedCheckLevel = qw(profile1 profile2 profile3);
        @supportedApiVer = qw(5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("VNETWORK",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	$success = 2;
        $desc = "Ensure that all vSwitch VLAN ID's are fully documented";
        $resolution = "Clearly label your portgroups";
        $code = "document-vlans";
        @supportedCheckLevel = qw(profile1 profile2 profile3);
        @supportedApiVer = qw(5.0.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("VNETWORK",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#NCN12
	$success = 2;
	$desc = "Fully document all VLANs used on vSwitches";
	$resolution = "Document all VLANs on vSwitches";
	if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
                $code = "verify-vlan-id";
        } else {
		$code = "NCN12";
	}
	@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("VNETWORK",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#NCN13
	$success = 2;
        $code = "NCN13";
	$desc = "Ensure that only authorized administrators have access to virtual networking components";
	$resolution = "Ensure authorized admins have access";
	@supportedCheckLevel = qw(enterprise);
        @supportedApiVer = qw(4.0.0 4.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("VNETWORK",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#NPN01
	$success = 2;
	$desc = "Ensure physical switch ports are configured with spanning tree disabled";
	$resolution = "Disable spanning tree on physical switches";
	if($host_api eq "5.0.0") {
                $code = "disable-stp";
        } else {
		$code = "NPN01";
	}
	@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("VNETWORK",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#NPN02
        $success = 2;
	$desc = "Ensure that the non-negotiate option is configured for trunk links between external physical switches and virtual switches in VST mode";
        $resolution = "Please refer to vNetwork doc for further details";
	if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
                $code = "set-non-negotiate";
        } else {
		$code = "NPN02";
	}
	@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("VNETWORK",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#NPN03
        $success = 2;
	$desc = "VLAN trunk links must be connected only to physical switch ports that function as trunk links";
        $resolution = "Self explanatory";
	if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
                $code = "verify-vlan-trunk";
        } else {
		$code = "NPN03";
	}
	@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("VNETWORK",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	$success = 2;
        $desc = "Verify that for virtual machines that route or bridge traffic spanning tree protocol is enabled and BPDU guard and Portfast are disabled on the upstream physical switch port";
	$resolution = "Please refer to vNetwork doc for further details";
	$code = "upstream-bpdu-stp";
	@supportedCheckLevel = qw(profile1 profile2 profile3);
        @supportedApiVer = qw(5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("VNETWORK",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	$success = 2;
        $desc = "Ensure that all dvSwitches PVLANS ID's are fully documented";
	$resolution = "dvSwitch PVLANS require primary and secondary VLAN ID's. These need to correspond to the ID's on external PVLAN-aware upstream switches if any";
        $code = "document-pvlans";
	@supportedCheckLevel = qw(profile1 profile2 profile3);
        @supportedApiVer = qw(5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
		&log("VNETWORK",$hostname,$code,$desc,$success,"N/A",$resolution);
	}

        $success = 2;
        $desc = "Ensure that VDS Netflow traffic is only being sent to authorized collector IPs";
        $resolution = "Please refer to vNetwork doc for further details";
        $code = "restrict-netflow-usage";
        @supportedCheckLevel = qw(profile1 profile2 profile3);
        @supportedApiVer = qw(5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("VNETWORK",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

        $success = 1;
        $desc = "Ensure that VDS Port Mirror traffic is only being sent to authorized collector ports or VLANs";
        $resolution = "Please refer to vNetwork doc for further details";
        $code = "restrict-portmirror-usage";
        @supportedCheckLevel = qw(profile1 profile2 profile3);
        @supportedApiVer = qw(5.1.0);
	my $vdsList;
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
		my $dvSwitches = Vim::find_entity_views(view_type => 'DistributedVirtualSwitch', properties => ['name','config']);
		foreach my $dvSwitch (@$dvSwitches) {
			if(defined($dvSwitch->{'config'}->vspanSession)) {
				$success = 0;
				$vdsList .= $dvSwitch->{'name'} . " ";	
			}
		}
		if($success eq 0) {
			$resolution = "Disable VDS Port Mirroring for " . $vdsList;
		}
                &log("VNETWORK",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

        $success = 1;
        $desc = "Disable VDS network healthcheck if you are not actively using it";
        $resolution = "N/A";
        $code = "limit-network-healthcheck";
        @supportedCheckLevel = qw(profile1 profile2 profile3);
        @supportedApiVer = qw(5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
		my $dvSwitches = Vim::find_entity_views(view_type => 'DistributedVirtualSwitch', properties => ['name','config']);
		foreach my $dvSwitch (@$dvSwitches) {
			if($dvSwitch->{'config'}->healthCheckConfig->[0]->enable || $dvSwitch->{'config'}->healthCheckConfig->[1]->enable) {
				$success = 0;
				$vdsList .= $dvSwitch->{'name'} . " ";
			}
		}
		if($success eq 0) {
			$resolution = "Disable VDS Network Health Check for " . $vdsList;
		} 
                &log("VNETWORK",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

        $success = 2;
        $desc = "Restrict port-level configuration overrides on VDS";
        $resolution = "Please refer to vNetwork doc for further details";
        $code = "restrict-port-level-overrides";
        @supportedCheckLevel = qw(profile1 profile2 profile3);
        @supportedApiVer = qw(5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("VNETWORK",$hostname,$code,$desc,$success,"N/A",$resolution);
        }
}

sub VMReport {
	my ($host_view,$product,$folder,$hostname,$host_username,$host_password,$check_level,$host_api) = @_;

	my $vms = Vim::get_views(mo_ref_array => $host_view->vm);
	my (%valuesToCheck,$code,$desc,$resolution,$req_check_level,@supportedApiVer,$deviceToCheck,@supportedCheckLevel);	
	my $check="";

	foreach(sort {lc($a->name) cmp lc($b->name)} @$vms) {
		my $vmname = $_->name;

		#SAMPLE LIST
		#next if($vmname ne "razor" && $vmname ne "UbuntuDev" && $vmname ne "scofield" && $vmname ne "William-XP" && $vmname ne "VCAC-5.1" && $vmname ne "STA202G" && $vmname ne "Synapse" && $vmname ne "reflex");

		#capture all advanced params and store in hash for reference
		&getAllAdvParams($_);

		my $devices = $_->config->hardware->device;

		#VMX01
		$success = 1;
		if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
                	%valuesToCheck = ("isolation.tools.diskWiper.disable","true");
                	$code = "disable-disk-shrinking-wiper";
                	$req_check_level = $check_level;
                	$desc = "Disable virtual disk shrinking";
                	@supportedApiVer = qw(5.0.0 5.1.0);
                	if(&checkApiVersion(\@supportedApiVer,$host_api)) {
                        	&queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
                	}
			$code = "disable-disk-shrinking-shrink";
                        %valuesToCheck = ("isolation.tools.diskShrink.disable","true");
                        if(&checkApiVersion(\@supportedApiVer,$host_api)) {
                                &queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
                        }
		} else {
			%valuesToCheck = ("isolation.tools.diskWiper.disable","true","isolation.tools.diskShrink.disable","true");	
			$code = "VMX01";
			$req_check_level = "enterprise";
			$desc = "Prevent Virtual Disk Shrinking";
			@supportedApiVer = qw(4.0.0 4.1.0);
        		if(&checkApiVersion(\@supportedApiVer,$host_api)) {
				&queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
			}
		}

		#VMX02
		$success = 1;
		if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
			if($check_level eq 'profile3') {
				$code = "limit-console-connections-one";
        	                $req_check_level = "profile3";
				%valuesToCheck = ("RemoteDisplay.maxConnections","1");
			} else {
				$code = "limit-console-connections-two";
                        	$req_check_level = $check_level;
				%valuesToCheck = ("RemoteDisplay.maxConnections","2");
                	}
                        $desc = "Limit sharing of console connections";
			@supportedApiVer = qw(5.0.0 5.1.0);
                        if(&checkApiVersion(\@supportedApiVer,$host_api)) {
                                &queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
                        }
		} else {
			%valuesToCheck = ("RemoteDisplay.maxConnections","1");
			$code = "VMX02";
			$req_check_level = "dmz";
			$desc = "Prevent others users from spying on Administrator remote consoles";
			@supportedApiVer = qw(4.0.0 4.1.0);
                	if(&checkApiVersion(\@supportedApiVer,$host_api)) {
				&queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
			}
		}

		#VMX03
		$success = 1;
		if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
			%valuesToCheck = ("isolation.tools.copy.disable","true");
			$code = "disable-console-copy";
			$desc = "Explicitly disable copy operations";
			@supportedApiVer = qw(5.0.0 5.1.0);
			$req_check_level = $check_level;
			if(&checkApiVersion(\@supportedApiVer,$host_api)) {
                                &queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
                        }

			%valuesToCheck = ("isolation.tools.paste.disable","true");
			$code = "disable-console-paste";
			$desc = "Explicitly disable paste operations";
			@supportedApiVer = qw(5.0.0 5.1.0);
			$req_check_level = $check_level;
			if(&checkApiVersion(\@supportedApiVer,$host_api)) {
                                &queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
                        }

			%valuesToCheck = ("isolation.monitor.control.disable","true");
                        $code = "disable-monitor-control";
                        $desc = "Disable VM Monitor Control";
                        @supportedApiVer = qw(5.0.0 5.1.0);
                        $req_check_level = $check_level;
                        if(&checkApiVersion(\@supportedApiVer,$host_api) && ($req_check_level eq "profile1")) {
                                &queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
                        }

			%valuesToCheck = ("isolation.tools.dnd.disable","false");
                        $code = "disable-console-dnd";
                        $desc = "Explicitly disable copy/paste operations";
                        @supportedApiVer = qw(5.0.0 5.1.0);
                        $req_check_level = $check_level;
                        if(&checkApiVersion(\@supportedApiVer,$host_api) && ($req_check_level eq "profile1")) {
                                &queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
                        }

			%valuesToCheck = ("isolation.tools.setGUIOptions.enable","false");
                        $code = "disable-console-gui-options";
                        $desc = "Explicitly disable copy/paste operations";
                        @supportedApiVer = qw(5.0.0 5.1.0);
                        $req_check_level = $check_level;
                        if(&checkApiVersion(\@supportedApiVer,$host_api) && ($req_check_level eq "profile1")) {
                                &queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
                        }
		} else {
			%valuesToCheck = ("isolation.tools.copy.disable","true","isolation.tools.paste.disable","true","isolation.tools.dnd.disable","true","isolation.tools.setGUIOptions.enable","false");
			$code = "VMX03";
			$req_check_level = "enterprise";
			$desc = "Disable Copy/Paste to Remote Console";
			@supportedApiVer = qw(4.0.0);
                	if(&checkApiVersion(\@supportedApiVer,$host_api)) {
				&queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
			}
		}

		#VMX10
	        $success = 2;
		$desc = "Disconnect unauthorized devices";
		if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
			$code = "disconnect-devices-floppy";
			@supportedApiVer = qw(5.0.0 5.1.0);
			$req_check_level = $check_level;
		} else {
	        	$code = "VMX10";
		        $req_check_level = "enterprise";
			@supportedApiVer = qw(4.0.0 4.1.0);
		}
		$deviceToCheck = "VirtualFloppy";	
		if($req_check_level eq "profile1" || $req_check_level eq "profile2") {
                	&checkDevice($devices,$vmname,$deviceToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
                }

		if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
                        $code = "disconnect-devices-serial";
                        @supportedApiVer = qw(5.0.0 5.1.0);
                        $req_check_level = $check_level;
                } else {
                        $code = "VMX10";
                        $req_check_level = "enterprise";
                        @supportedApiVer = qw(4.0.0 4.1.0);
                }
                $deviceToCheck = "VirtualSerialPort";
                if($req_check_level eq "profile1" || $req_check_level eq "profile2") {
                	&checkDevice($devices,$vmname,$deviceToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
                }

		if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
                        $code = "disconnect-devices-parallel";
                        @supportedApiVer = qw(5.0.0 5.1.0);
                        $req_check_level = $check_level;
                } else {
                        $code = "VMX10";
                        $req_check_level = "enterprise";
                        @supportedApiVer = qw(4.0.0 4.1.0);
                }
                $deviceToCheck = "VirtualParallelPort";
                if($req_check_level eq "profile1" || $req_check_level eq "profile2") {
                	&checkDevice($devices,$vmname,$deviceToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
                }

		if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
                        $code = "disconnect-devices-usb";
                        @supportedApiVer = qw(5.0.0 5.1.0);
                        $req_check_level = $check_level;
                } else {
                        $code = "VMX10";
                        $req_check_level = "enterprise";
                        @supportedApiVer = qw(4.0.0 4.1.0);
                }
                $deviceToCheck = "VirtualUSB";
                if($req_check_level eq "profile1" || $req_check_level eq "profile2") {
                        &checkDevice($devices,$vmname,$deviceToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
                }

		if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
                        $code = "disconnect-devices-ide";
                        @supportedApiVer = qw(5.0.0 5.1.0);
                        $req_check_level = $check_level;
                } else {
                        $code = "VMX10";
                        $req_check_level = "enterprise";
                        @supportedApiVer = qw(4.0.0 4.1.0);
                }
                $deviceToCheck = "VirtualIDEController";
                if($req_check_level eq "profile1" || $req_check_level eq "profile2") {
	                &checkDevice($devices,$vmname,$deviceToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
                }

		#VMX11
		$success = 1;
		if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
			$code = "prevent-device-interaction-connect";
			%valuesToCheck = ("isolation.device.connectable.disable","true");
			$desc = "Prevent unauthorized removal connection and modification of devices";
			$req_check_level = $check_level;
			@supportedApiVer = qw(5.0.0 5.1.0);
                        if(&checkApiVersion(\@supportedApiVer,$host_api)) {
                                &queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
                        }

			$code = "prevent-device-interaction-edit";
			%valuesToCheck = ("isolation.device.edit.disable","true");
                        if(&checkApiVersion(\@supportedApiVer,$host_api)) {
                                &queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
                        }
		} else {
	                %valuesToCheck = ("isolation.device.connectable.disable","true","isolation.device.edit.disable","true");
			$code = "VMX11";
			$desc = "Prevent Unauthorized Removal or Connection of Devices";
			$req_check_level = "enterprise";
			@supportedApiVer = qw(4.0.0 4.1.0);
                	if(&checkApiVersion(\@supportedApiVer,$host_api)) {
				&queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
			}
		}

		#VMX12
		$success = 1;
		%valuesToCheck = ("vmci0.unrestricted","false");
                $desc = "Disable VM-to-VM communication through VMCI";
		if($host_api eq "5.0.0") {
			$code = "disable-intervm-vmci";
		} else {
			$code = "VMX12";
		}
		@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
	        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0);
        	if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
			&queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
		}

		#VMX20
		$success = 1;
		$code = "VMX20";
		$desc = "VM log file size and number should be limited";
		if($check_level eq 'enterprise') {
                        %valuesToCheck = ("log.rotateSize","1000000","log.keepOld","10");
                        $req_check_level = "enterprise";
                } elsif($check_level eq 'sslf') {
                        %valuesToCheck = ("logging","false");
                        $req_check_level = "sslf";
                }
		@supportedApiVer = qw(4.0.0 4.1.0);
                if(&checkApiVersion(\@supportedApiVer,$host_api)) {
			&queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
		}

		#VMX21
		$success = 1;
		%valuesToCheck = ("tools.setInfo.sizeLimit","1048576");
		$desc = "Limit informational messages from the VM to the VMX file";
		if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
                        $code = "limit-setinfo-size";
		} else {
			$code = "VMX21";
		}
		@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
	        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        	if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
	                &queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
                }

		#VMX22
                $success = 1;
		$desc = "Avoid using independent nonpersistent disks";
		$resolution = "N/A";
		if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
			$code = "disable-independent-nonpersistent";
		} else {
			$code = "VMX22";
		}
		@supportedCheckLevel = qw(dmz profile1 profile2);
                @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
                if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
			foreach(@$devices) {
        	        	if($_->isa('VirtualDisk') && $_->backing->diskMode eq "independent_nonpersistent") {
                	              	$success = 0;
                        	       	$resolution = "VM contains independent non-persistent disk";
                                 	last;
                               	}
	               	}
                       	&log("VM",$vmname,$code,$desc,$success,"N/A",$resolution);
		}

		#VMX23
                $success = 2;
                $desc = "Use secure protocols for virtual serial port access";
		if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
                        $code = "use-secure-serial-communication";
                } else {
			$code = "VMX23";
		}
		@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
                @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
                if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                        &log("VM",$vmname,$code,$desc,$success,"N/A",$resolution);
                }
		
		#VMX24
                $success = 2;
		$desc = "Disable certain unexposed features";
		if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
			$req_check_level = $check_level;
			@supportedApiVer = qw(5.0.0 5.1.0);
			if($req_check_level eq "profile1" || $req_check_level eq "profile2") {
				$code = "disable-unexposed-features-unitypush";
				%valuesToCheck = ("isolation.tools.unity.push.update.disable","true");
				if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                                        &queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
                                }
				
				$code = "disable-unexposed-features-launchmenu";
				%valuesToCheck = ("isolation.tools.ghi.launchmenu.change","true");
				if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                                        &queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
                                }

				$code = "disable-unexposed-features-memsfss";
				%valuesToCheck = ("isolation.tools.memSchedFakeSampleStats.disable","true");
				if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                                        &queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
				}		

				$code = "disable-unexposed-features-getcreds";
				%valuesToCheck = ("isolation.tools.getCreds.disable","true");
				if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
        	                        &queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
	                        }

				$code = "disable-unexposed-features-autologon";
				%valuesToCheck = ("isolation.tools.ghi.autologon.disable","true");
                                if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                                        &queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
                                }
				
				$code = "disable-unexposed-features-biosbbs";
				%valuesToCheck = ("isolation.bios.bbs.disable","true");
				$check_level = "profile1";
                                if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                                        &queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
                                }

				$code = "disable-hgfs";
                                %valuesToCheck = ("isolation.tools.hgfsServerSet.disable","true");
                                if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                                        &queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
                                }

				$code = "disable-unexposed-features-protocolhandler";
				%valuesToCheck = ("isolation.tools.ghi.protocolhandler.info.disable","true");
				if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                                        &queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
                                }

				$code = "disable-unexposed-features-shellaction";
				%valuesToCheck = ("isolation.ghi.host.shellAction.disable","true");
				if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                                        &queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
                                }

				$code = "disable-unexposed-features-toporequest";
				%valuesToCheck = ("isolation.tools.dispTopoRequest.disable","true");
				if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                                        &queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
                                }
	
				$code = "disable-unexposed-features-trashfolderstate";
				%valuesToCheck = ("isolation.tools.trashFolderState.disable","true");
				if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                                        &queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
                                }

				$code = "disable-unexposed-features-trayicon";
				%valuesToCheck = ("isolation.tools.ghi.trayicon.disable","true");
				if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                                        &queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
                                }

				$code = "disable-unexposed-features-unity";
				%valuesToCheck = ("isolation.tools.unity.disable","true");
				if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                                        &queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
                                }

				$code = "disable-unexposed-features-unity-interlock";
				%valuesToCheck = ("Isolation.tools.unityInterlockOperation.disable","true");
				if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                                        &queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
                                }

				$code = "disable-unexposed-features-unity-taskbar";
				%valuesToCheck = ("isolation.tools.unity.taskbar.disable","true");
				if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                                        &queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
                                }

				$code = "disable-unexposed-features-unity-unityactive";
				%valuesToCheck = ("isolation.tools.unityActive.disable","true");
				if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                                        &queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
                                }

				$code = "disable-unexposed-features-unity-windowcontents";
				%valuesToCheck = ("isolation.tools.unity.windowContents.disable","true");
				if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                                        &queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
                                }

				$code = "disable-unexposed-features-versionget";
				%valuesToCheck = ("isolation.tools.vmxDnDVersionGet.disable","true");
				if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                                        &queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
                                }

				$code = "disable-unexposed-features-versionset";
				%valuesToCheck = ("isolation.tools.guestDnDVersionSet.disable","true");	
				if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                                        &queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
                                }
			}
		} else {
        	        $code = "VMX24";
			if($check_level eq 'dmz') {
                	        %valuesToCheck = ("isolation.tools.unity.push.update.disable","true","isolation.tools.ghi.launchmenu.change","true","isolation.tools.memSchedFakeSampleStats.disable","true","isolation.tools.getCreds.disable","true");
        	                $req_check_level = "dmz";
	                } elsif($check_level eq 'sslf') {
                        	%valuesToCheck = ("isolation.tools.hgfsServerSet.disable","true");
                	        $req_check_level = "sslf";
        	        }
	                @supportedApiVer = qw(4.1.0);
			if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
				&queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
			}
		}

		#VMX30
		$success = 1;
		%valuesToCheck = ("guest.commands.enabled","false");
		$code = "VMX30";
		$desc = "Disable remote operations within the guest";
		@supportedCheckLevel = qw(dmz);
                @supportedApiVer = qw(4.0.0 4.1.0);
                if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
			&queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);	
		}

		#VMX31
		$success = 1;
                %valuesToCheck = ("tools.guestlib.enableHostInfo","false");
		$desc = "Do not send host performance information to guests";
		if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
                        $code = "restrict-host-info";
		} else {
			$code = "VMX31";
		}
		@supportedCheckLevel = qw(enterprise profile1 profile2);
                @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
                if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
			&queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
		}

		$success = 1;
                %valuesToCheck = ("isolation.tools.autoInstall.disable","true");
                $desc = "Disable tools auto install";
                $code = "disable-autoinstall";
		@supportedCheckLevel = qw(profile1 profile2);
                @supportedApiVer = qw(5.0.0 5.1.0);
                if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                        &queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
                }

		$success = 1;
                %valuesToCheck = ("logging","false");
                $desc = "Disable VM logging";
                $code = "disable-logging";
                @supportedCheckLevel = qw(profile1);
                @supportedApiVer = qw(5.0.0 5.1.0);
                if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
			&log("VM",$vmname,$code,$desc,$success,"logging=false must be manually added to .vmx","Please refer to VM doc for further details");
                }

		$success = 1;
                %valuesToCheck = ("isolation.tools.vixMessage.disable","true");
                $desc = "Disable VIX messages from the VM";
                $code = "disable-vix-messages";
                @supportedCheckLevel = qw(profile1);
                @supportedApiVer = qw(5.0.0 5.1.0);
                if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                        &queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
                }

		$success = 1;
                %valuesToCheck = ("log.keepOld","10");
                $desc = "Limit VM logging";
                $code = "limit-log-number";
                @supportedCheckLevel = qw(profile2 profile3);
                @supportedApiVer = qw(5.0.0 5.1.0);
                if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                        &queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
                }

		$success = 1;
                %valuesToCheck = ("log.rotateSize","100000");
                $desc = "Limit VM logging";
                $code = "limit-log-size";
                @supportedCheckLevel = qw(profile1 profile3);
                @supportedApiVer = qw(5.0.0 5.1.0);
                if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                        &queryVMAdvConfiguration(\%vms_all_adv_params,$vmname,\%valuesToCheck,$code,$desc,$resolution,$check_level,$req_check_level);
                }

		#VMX51
                $success = 2;
		$desc = "Control access to VMsafe CPU/Mem APIs";
                $resolution = "Please refer to VM doc for further details";
		my $param = "vmsafe.enable";
		if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
			$code = "verify-vmsafe-cpumem-enable";
		} else {
	                $code = "VMX51";
		}
		@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
                @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
                if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                        &log("VM",$vmname,$code,$desc,$success,$param,$resolution);
                }

		#VMX52
                $success = 2;
		$desc = "Control access to VMsafe CPU/Mem APIs";
                $resolution = "Please refer to VM doc for further details";
                $param = "vmsafe.agentAddress";
		if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
                        $code = "verify-vmsafe-cpumem-agentaddress";
                } else {
                	$code = "VMX52";
		}
		@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
                @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
                if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                        &log("VM",$vmname,$code,$desc,$success,$param,$resolution);
                }

		#VMX54
                $success = 2;
		$desc = "Control access to VMsafe CPU/Mem APIs";
                $resolution = "Please refer to VM doc for further details";
                $param = "vmsafe.agentPort";
		if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
                        $code = "verify-vmsafe-cpumem-agentport";
                } else {
                	$code = "VMX54";
		}
		@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
                @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
                if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                        &log("VM",$vmname,$code,$desc,$success,$param,$resolution);
                }

		#VMX55
		$success = 2;
		$desc = "Control access to virtual machines through VMsafe network APIs";
                $resolution = "Please refer to VM doc for further details";
		if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
                        $code = "verify-network-filter";
                } else {
                	$code = "VMX55";
		}
		@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
                @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
                if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                        &log("VM",$vmname,$code,$desc,$success,"N/A",$resolution);
                }

		#VMX56
                $success = 2;
                $code = "VMX56";
                $desc = "Restrict access to VMsafe network APIs";
                $resolution = "Please refer to VM doc for further details";
		@supportedCheckLevel = qw(enterprise);
                @supportedApiVer = qw(4.1.0);
                if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                        &log("VM",$vmname,$code,$desc,$success,"N/A",$resolution);
                }
	
		#VMP01
		$success = 2;
		$desc = "Secure Virtual Machines as You Would Secure Physical Machines";
                $resolution = "Please refer to VM doc for further details";
		if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
                        $code = "secure-guest-os";
		} else {
        	        $code = "VMP01";
		}
		@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
                @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
                if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
	                &log("VM",$vmname,$code,$desc,$success,"N/A",$resolution);
                }

		#VMP02
                $success = 2;
		$desc = "Disable unnecessary or superfluous functions inside VMs";
                $resolution = "Please refer to VM doc for further details";
		if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
			$code = "disable-unnecessary-functions";
		} else {	
	                $code = "VMP02";
		}
		@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
                @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
                if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
	                &log("VM",$vmname,$code,$desc,$success,"N/A",$resolution);
                }

		#VMP03
                $success = 2;
		$desc = "Use Templates to deploy VMs whenever possible";
                $resolution = "Please refer to VM doc for further details";
		if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
                        $code = "use-vm-templates";
                } else {	
			$code = "VMP03";
		}
		@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
                @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
                if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                        &log("VM",$vmname,$code,$desc,$success,"N/A",$resolution);
                }

		#VMP04
                $success = 2;
		$desc = "Prevent Virtual Machines from Taking Over Resources";
                $resolution = "Please refer to VM doc for further details";
		if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
                        $code = "control-resource-usage";
		} else {	
	                $code = "VMP04";
		}
		@supportedCheckLevel = qw(dmz profile1 profile2);
                @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
                if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                        &log("VM",$vmname,$code,$desc,$success,"N/A",$resolution);
                }

		#VMP05
                $success = 2;
		$desc = "Minimize Use of the VM Console";
                $resolution = "Please refer to VM doc for further details";
		if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
                        $code = "minimize-console-use";
		} else {
        	        $code = "VMP05";
		}
		@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
                @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
                if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
			&log("VM",$vmname,$code,$desc,$success,"N/A",$resolution);
                }

		#clear previous data
		%vms_all_adv_params = ();
	}
}
	
sub HOSTReport {
	my ($host_view,$product,$folder,$hostname,$host_username,$host_password,$check_level,$host_api) = @_;

	my ($services,$code,$success,$desc,$resolution,$req_check_level,@supportedApiVer,@supportedCheckLevel);

	#HIN01
	$success = 2;
	$desc = "Verify integrity of software before installation";
        $resolution = "Verify SHA1 hash after downloading from VMware";
	if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
		$code = "verify-install-media";
	} else {
        	$code = "HIN01";
	}
	@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#HIN02
        $success = 2;
	$desc = "Keep ESX/ESXi system properly patched";
        $resolution = "N/A";
	if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
                $code = "apply-patches";
	} else {
        	$code = "HIN02";
	}
	@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
        }
	
	#HST01
	$success = 1;
	$desc = "Ensure Bidirectional CHAP Authentication is enabled for iSCSI traffic";
	if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
		$code = "enable-chap-auth";
		$req_check_level = $check_level;
	} else {
	        if($check_level eq 'dmz') {
        	        $req_check_level = "dmz";
	        } elsif($check_level eq 'sslf') {
        	        $req_check_level = "sslf";
	        } else {
			$req_check_level = "";
		}
	}
	@supportedCheckLevel = qw(dmz profile1 profile2 profile3);
	@supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
		my @mutualChapSecrets = ();
		my @chapSecrets = ();

		my $storageSys = Vim::get_view(mo_ref => $host_view->configManager->storageSystem);
		if($storageSys->storageDeviceInfo->softwareInternetScsiEnabled) {
			my $hbas = $storageSys->storageDeviceInfo->hostBusAdapter;
			foreach(@$hbas) {
				if($_->isa('HostInternetScsiHba')) {
					my $authCapablities = $_->authenticationCapabilities;
					my $authProperties = $_->authenticationProperties;
	
					#mutual chap supported
					if($authCapablities->chapAuthSettable && $authCapablities->targetChapSettable && $authCapablities->targetMutualChapSettable) {
						if($authProperties->mutualChapAuthenticationType ne 'Use CHAP' || !defined($authProperties->mutualChapName) || $authProperties->mutualChapName eq '' || !defined($authProperties->mutualChapSecret) || $authProperties->mutualChapSecret eq '') {
							$success = 0;
							if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
                                                        	$code = "enable-chap-auth";
                                                	} else {
                                                        
								$code = "HST01";
							}
							$resolution = "Please refer to the HOST doc for further details";
							&log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);	
						} else {
							if(! grep(/$authProperties->mutualChapSecret/,@mutualChapSecrets)) {
								push @mutualChapSecrets,$authProperties->mutualChapSecret;
							} else {
								$success = 0;
								$desc = "Ensure uniqueness of CHAP authentication secrets";
								$resolution = "CHAP \"names\" and \"secrets\" should be unique";
								if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
                                                        		$code = "unique-chap-secrets";
        	                                                        &log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
                                                		} else {
									$code = "HST02";
									$desc = "Ensure uniqueness of CHAP authentication secrets";
									$resolution = "CHAP \"names\" and \"secrets\" should be unique";
									&log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
								}
							}
						}
					}
					
					#standard chap
					if(!$authProperties->chapAuthEnabled) {
						$success = 0;
						if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
							$code = "enable-chap-auth";
						} else {
							$code = "HST01";
						}
						$resolution = "CHAP should not be disabled when using iSCSI";
						&log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
					}
					if(!defined($authProperties->chapName) || $authProperties->chapName eq '') {
						$success = 0;
						if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
                                                        $code = "enable-chap-auth";
                                                } else {
                                                        $code = "HST01";
						}
						$resolution = "CHAP name should be configured";
						&log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
					}
					if(!defined($authProperties->chapSecret) || $authProperties->chapSecret  eq '') {
						$success = 0;
						if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
                                                        $code = "enable-chap-auth";
                                                } else {
                                                        $code = "HST01";
						}
						$resolution = "CHAP secret should be configured";
						&log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
                                	} else {
                                		if(! grep(/$authProperties->chapSecret/,@chapSecrets)) {
                                        		push @chapSecrets,$authProperties->chapSecret;
	                                        } else {
        	                                	$success = 0;
							$desc = "Ensure uniqueness of CHAP authentication secrets";
							$resolution = "CHAP secrets should be unique";
							if($host_api eq "5.0.0") {
                                                 		$code = "unique-chap-secrets";
								&log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
                                                	} else {
								$code = "HST02";
								&log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
							}
                        	                }
                                	}
				}
			}
		}
		if($success eq 1) {
                        $resolution = "N/A";
			&log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
		}
	}

	$success = 2;
        $code = "vmdk-zero-out";
	$desc = "Zero out VMDK files prior to deletion";
        $resolution = "Please refer to the HOST doc for further details";
        @supportedCheckLevel = qw(profile1 profile2);
        @supportedApiVer = qw(5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#HST03
	$success = 2;
	$desc = "Mask and zone SAN resources appropriately";
        $resolution = "Zoning and masking capabilities for each SAN switch and disk array are vendor specific as are the tools for managing LUN masking";
	if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
		$code = "mask-zone-san";
	} else {	
        	$code = "HCT03";
	}
	@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#HCM01
	$success = 1;
	#$desc = "Do not use default self-signed certificates for ESX/ESXi communication";
	$desc = "Configure SSL read timeouts and/or handshake timeouts";
	if($host_api eq "5.0.0") {
		$code = "ssl-readtimeout";
	} else {
		$code = "HCM01";
	}

	################################################################
	# VALIDATE WHETHER OR NOT ENDPOING SERVICES HAVE BEEN DISABLED #
	################################################################
	my ($rootEP,$hostEP,$mobEP,$uiEP) = (0,0,0,0);

	if($hosttype ne 'VirtualCenter') {
		$rootEP = &validateEndPoint($hostname,"");
		$mobEP  = &validateEndPoint($hostname,"mob");
		if($product ne "embeddedEsx") {
			$uiEP = &validateEndPoint($hostname,"ui");
		}
		$hostEP = &validateEndPoint($hostname,"host");		

		if($hostEP) {
			&downloadFile("host","proxy.xml","$folder/proxy.xml","HOST",$hostname,$code,$desc);
		}
	}

	@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
		if($hosttype eq 'VirtualCenter') {
                        $success = 2;
			$resolution = "Please refer to Host doc for further details OR run directly report against ESX(i) host";
			&log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
                } else {
			if($rootEP) {
				#download /host/hostAgentConfig.xml
				&downloadFile("host","hostAgentConfig.xml","$folder/hostAgentConfig.xml",$hostname,$code,$desc);
				my $ssltimeout_results = `grep -iE '(readTimeoutsMs|handshakeTimeoutMs)' "$folder/hostAgentConfig.xml"`;
				if($ssltimeout_results eq '') {
					$success = 0;
					$resolution = "hostAgentConfig.xml for SSL should contain readTimeoutsMs and/or handshakeTimeoutMs. Please refer to the ESX(i) Configuration Guide";
				} else {
					$success = 1;
				}
			} else {
				$success = 2;
				$resolution = "Manual verification required since remote URL path has been disabled";
			}
			if($success eq 1) {
                        	$resolution = "N/A";
			}
			&log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
		}
	}

	# download SSL cert from remote host
	my $download_ssl = `echo '' | openssl s_client -connect $hostname:443 2> $folder/tmp 1> $folder/ssl_cert`;

	$success = 1;
	$code = "esxi-no-self-signed-certs";
	$desc = "Do not use default self-signed certificates for ESX/ESXi communication";
	@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
	if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
		my $openssl_results = `openssl x509 -in "$folder/ssl_cert" -issuer -sha1 -noout | grep "issuer"`;
		chomp($openssl_results);
		if($openssl_results =~ m/issuer= \/O=VMware Installer/) {
			$success = 0;
			$resolution = "VMware default SSL cert should not be used";
		} else {
			$success = 1;
			$resolution = "N/A";
		}
		&log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
	}

	$success = 1;
	$code = "check-host-ssl-cert-expiry";
	$desc = "Verify SSL Certificate expiry";
	@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
	@supportedApiVer = qw(4.0.0 4.1.0 5.0.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
		my $openssl_results = `openssl x509 -noout -in "$folder/ssl_cert" -enddate | awk -F 'notAfter=' '{print \$2}' | awk '{print \$1, \$2, \$4}'`;
		if($openssl_results) {
			my $todays_date = &giveMeDate('YMD');
			my $ssl_date = &getSSLDate($openssl_results);
			my $diff = &days_between($todays_date,$ssl_date);
			if($diff <= 10) {
				$success = 0;
                                $resolution = "SSL Certificate expiration in $diff days!";
                                &log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
			} else {
				$success = 1;
				$resolution = "SSL Certificate has not expired";
				&log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
			}
		} else {
			$success = 2;
			$resolution = "Could not verify SSL Certificate expiry";
			&log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
		}
	}

	#HCM02
	$success = 1;
	$desc = "Disable Managed Object Browser";
	$resolution = "<a href=\"https://$hostname/mob\">https://$hostname/mob</a> should be disabled";
	if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
		$code = "disable-mob";
	} else {
		$code = "HCM02";
	}
	@supportedCheckLevel = qw(sslf profile1 profile2 profile3);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
		if($hosttype eq 'VirtualCenter') {
                        $success = 2;
			my $vmobEP = &validateEndPoint($hostname,"mob");
			if($vmobEP eq 1) {
				$success = 0;
			}
                } else {
			# pass
			if($mobEP eq 0) {
                                $success = 1;
                                $resolution = "N/A";
			# fail
                        } elsif($mobEP eq 1) {
                                $success = 0;
			# unconfirmed
                        } else {
                                $success = 2;
                                $resolution = "Unable to verify please manually verify URL";
                        }
		}
		&log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
	}

	#HCM3
	if($product eq "esx") {
		$success = 1;
		$code = "HCM03";
		$desc = "Disable Web Access (ESX ONLY)";
		$resolution = "<a href=\"https://$hostname/ui\">https://$hostname/ui</a> should be disabled";
		$req_check_level = "dmz";
		@supportedApiVer = qw(4.0.0 4.1.0);
	        if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
			my $serviceSys = Vim::get_view(mo_ref => $host_view->configManager->serviceSystem);
			$services = $serviceSys->serviceInfo->service;
			foreach(@$services) {
				if($_->key eq 'vmware-webAccess') {
					if($_->running) {
						$success = 0;
					}
				}
			}
			if($success eq 1) {
        	                $resolution = "N/A";
                	}
			&log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
		}
	}

	#HCM04
	$success = 1;
	$code = "HCM04";
	$desc = "Ensure ESX is Configured to Encrypt All Sessions";
        $req_check_level = "enterprise";
	@supportedApiVer = qw(4.0.0);
        if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
		if($hosttype eq 'VirtualCenter') {
			$success = 2;
			$resolution = "Please verify that &#60;httpPort/&#62; & &#60;accessMode/&#62; in proxy.xml is not configured to allow HTTP";
		} else {
			if($hostEP) {
				my $proxy_entries = `grep -i "e id" "$folder/proxy.xml" | /usr/bin/wc -l`;
				my $httpport_results = `grep -i "<httpPort>-1</httpPort>" "$folder/proxy.xml" | /usr/bin/wc -l`;
				if($proxy_entries != $httpport_results) {
					$success = 0;
					$resolution = "&#60;httpPort&#62; in proxy.xml should not be configured to allow HTTP";
					&log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
				}
	
				my $accessmode_results = `grep -i "<accessMode>" "$folder/proxy.xml" | grep -iE '(httpAndHttp|httpsOnl)'`;
				if($accessmode_results ne '') {
					$success = 0;
					$resolution = "&#60;accessMode&#62; in proxy.xml should not be configured to allow HTTP";
					&log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
				}
			} else {
                                $success = 2;
                                $resolution = "Manual verification required since remote URL path has been disabled";
                        }
			if($success eq 1) {
                        	$resolution = "N/A";
        	        }
		}
		&log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
	}

	#HCM05
        $success = 1;
        $desc = "Disable Welcome web page";
	$resolution = "<a href=\"https://$hostname/\">https://$hostname/</a> should be disabled";
	if($host_api eq "5.0.0") {
		$code = "disable-welcome-page";
	} else {
		$code = "HCM05";
	}
	@supportedCheckLevel = qw(dmz profile1 profile2 profile3);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                if($hosttype eq 'VirtualCenter') {
                        $success = 2;
			my $vrootEP = &validateEndPoint($hostname,"");
                        if($vrootEP eq 1) {
                                $success = 0;
                        }
                } else {
			# pass
			if($rootEP eq 0) {
				$success = 1;
				$resolution = "N/A";
			# fail
			} elsif($rootEP eq 1) {
				$success = 0;
			# unable to verify
			} else {
				$success = 2;
                                $resolution = "Unable to verify please manually verify URL";
			}
                }
		&log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution)
	}

	#HCM06
	$success = 2;
	$desc = "Use SSL for Network File Copy (NFC)";
	$resolution = "Add &#60;nfc&#62;&#60;useSSL&#62;true&#60;/useSSL&#62;&#60;/nfc&#62; to vCenter vpxd.cfg";
	if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
		$code = "enable-nfc-ssl";
	} else {
		$code = "HCM06";
	}
	@supportedCheckLevel = qw(sslf profile1);
        @supportedApiVer = qw(4.1.0 5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#HLG01
	$success = 1;
	$desc = "Configure remote syslog";
        $resolution = "Remote syslog should be configured";
	if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
		$code = "enable-remote-syslog";
	} else {	
		$code = "HLG01";
	}
	@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
		if($hosttype eq 'VirtualCenter') {
			$resolution = "Verify syslog is configured";
			if($product eq 'esx') {
				if($hostEP) {
					&downloadFile("host","syslog.conf","$folder/syslog.conf","HOST",$hostname,$code,$desc);
					my $syslog_results = `grep -i "@" "$folder/syslog.conf"`;
					if($syslog_results eq '') {
						$success = 0;
					}
				} else {
                                	$success = 2;
                                	$resolution = "Manual verification required since remote URL path has been disabled";
				}
                        }

			if($product eq "embeddedEsx") {
                        	my $advOpt = Vim::get_view(mo_ref => $host_view->configManager->advancedOption);
                        	my $results;
                        	eval {
                                	if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
                        	        	$results = $advOpt->QueryOptions(name => 'Syslog.global.logHost');
                                	} else {
                                        	$results = $advOpt->QueryOptions(name => 'Syslog.Remote.Hostname');
                                	}
                                	foreach(@$results) {
                                		if($_->value eq "") {
                                        		$success = 0;
                                        	}
                                	}
                                };
                                if($@) {
                                	$success = 0;
                                }
                	}
		}
		if($success eq 1) {
 	               $resolution = "N/A";
                }
		&log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
	}

	#HLG02
        $success = 1;
	$desc = "Configure persistent logging";
        $resolution = "Please refer to HOST doc for further details";
	if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
		$code = "config-persistent-logs";
		@supportedCheckLevel = qw(profile1 profile2 profile3);
		@supportedApiVer = qw(5.0.0 5.1.0);
		my $advOpt = Vim::get_view(mo_ref => $host_view->configManager->advancedOption);
                my $results;
                eval {
                	$results = $advOpt->QueryOptions(name => 'Syslog.global.logDir');
                	foreach(@$results) {
                		if($_->value eq "") {
                        		$success = 0;
                        	}
                	}
                };
                if($@) {
                	$success = 0;
                } else { 
			$resolution = "N/A";
		}
		if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                        &log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
                }
	} else {
        	$code = "HLG02";
		@supportedCheckLevel = qw(enteprise);
		@supportedApiVer = qw(4.0.0 4.1.0);
		if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
			&log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
		}
	}

	$success = 1;
	$code = "enable-ad-auth";
	$desc = "Use Active Directory for local user authentication";
	$resolution = "Please refer to the HOST doc for further details";
	@supportedCheckLevel = qw(profile1 profile2 profile3);
        @supportedApiVer = qw(5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
		my $authManager = Vim::get_view(mo_ref => $host_view->configManager->authenticationManager);
		my $authStores = $authManager->info->authConfig;
		foreach (@$authStores) {
			if($_->isa('HostActiveDirectoryInfo') && !$_->enabled) {
				$success = 0;
			}
		}
                &log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	$success = 2;
        $code = "enable-auth-proxy";
	$desc = "When adding ESXi hosts to Active Directory use the vSphere Authentication Proxy to protect passwords";
	$resolution = "Please refer to the HOST doc for further details";
	@supportedCheckLevel = qw(profile1 profile2 profile3);
        @supportedApiVer = qw(5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	$success = 2;
	$desc = "Verify Image Profile and VIB Acceptance Levels";
	$resolution = "N/A";
	@supportedCheckLevel = qw(profile1 profile2 profile3);
        @supportedApiVer = qw(5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$req_check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
		my $imageConfig = Vim::get_view(mo_ref => $host_view->configManager->imageConfigManager);
		eval {
			my $acceptance = $imageConfig->HostImageConfigGetAcceptance();
			if($req_check_level eq "profile1" && $acceptance ne "vmware_certified") {
				$success = 0;
				$code = "verify-acceptance-level-accepted";
				$resolution = "Please refer to the HOST doc for further details";
			} elsif($req_check_level eq "profile1" && $acceptance eq "vmware_certified") {
				$code = "verify-acceptance-level-accepted";
				$resolution = "Image Profile is configured to the proper acceptance level you will need to manually verify VIB acceptance level";
			} elsif($req_check_level eq "profile2" && ($acceptance ne "vmware_certified" || $acceptance ne "vmware_accepted")) {
				$success = 0;
				$code = "verify-acceptance-level-certified";
                                $resolution = "Please refer to the HOST doc for further details";
			} elsif($req_check_level eq "profile2" && ($acceptance eq "vmware_certified" || $acceptance eq "vmware_accepted")) {
				$code = "verify-acceptance-level-certified";
				$resolution = "Image Profile is configured to the proper acceptance level you will need to manually verify VIB acceptance level";
			} elsif($req_check_level eq "profile3" && $acceptance ne "vmware_accepted") {
				$success = 0;
				$code = "verify-acceptance-level-supported";
                                $resolution = "Please refer to the HOST doc for further details";
			} elsif($req_check_level eq "profile3" && $acceptance eq "vmware_accepted") {
				$code = "verify-acceptance-level-supported";
				$resolution = "Image Profile is configured to the proper acceptance level you will need to manually verify VIB acceptance level";
			}
			#WILLIAM
		};
		if($@) {
			$success = 0;
		}
                &log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	$success = 2;
        $code = "config-firewall-access";
        $desc = "Configure the ESXi host firewall to restrict access to services running on the host";
        $resolution = "Please refer to the HOST doc for further details";
	@supportedCheckLevel = qw(profile1 profile2 profile3);
        @supportedApiVer = qw(5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#HLG03
	$success = 1;
	$desc = "Configure NTP time synchronization";
        $resolution = "NTP should be configured";
	if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
		$code = "config-ntp";
	} else {
		$code = "HLG03";
	}
	@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
		foreach(@$services) {
		        if($_->key eq 'ntpd') {
        		        if($_->running) {
                	        	$success = 0;
                	        }
         	       }
        	}
		if($success eq 1) {
                        $resolution = "N/A";
                }
		&log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
	}
	
	#HMT01
	$success = 2;
	$desc = "Do not provide root/administrator level access to CIM-based hardware monitoring tools or other 3rd party applications";
	$resolution = "Please refer to the HOST doc for further details";
	if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
		$code = "limit-cim-access";
	} else {
		$code = "HMT01";
	}
	@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	$success = 2;
	$desc = "Remove keys from SSH authorized_keys file";
	$resolution = "Please refer to the HOST doc for further details";
	$code = "remove-authorized-keys";
	@supportedCheckLevel = qw(profile1 profile2 profile3);
        @supportedApiVer = qw(5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#HMT02
	$success = 1;
	$desc = "Ensure proper SNMP configuration";
	if($host_api eq "5.0.0" || $host_api eq "5.1.0" ) {
		$code = "config-snmp";
	} else {
		$code = "HMT02";
	}
	@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
		if($product eq 'embeddedEsx') {
			my $snmpSys; 
			eval {
				$snmpSys = Vim::get_view(mo_ref => $host_view->configManager->snmpSystem);
			};
			if(!$@) {
				if($snmpSys->configuration->enabled) {
					if(!defined($snmpSys->configuration->port)) {
						$success = 0;
						$resolution = "SNMP is enabled but port is not configured";
					}
					if(!defined($snmpSys->configuration->readOnlyCommunities)) {
						$success = 0;
						$resolution = "SNMP is enabled but read only communities is not configured";
					}
					if(!defined($snmpSys->configuration->trapTargets)) {
						$success = 0;
						$resolution = "SNMP is enabled but trap targets are not configured";
					}
				}
			} else {
				$success = 0;
				$resolution = "SNMP is not configured on the host";
			}
			if($success eq 1) {
                	        $resolution = "N/A";
	                }
			&log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
		}
	}

	#HMT03
        $success = 2;
	$desc = "Verify contents of exposed configuration files";
	$resolution = "<a href=\"https://$hostname/host\">https://$hostname/host</a> is available and should be monitored for file intergrity";
	if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
		$code = "verify-config-files";
	} else {
        	$code = "HMT03";
	}
	@supportedCheckLevel = qw(dmz profile1);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#HMT10
	$success = 2;
        $code = "HMT10";
	$desc = "Prevent unintended use of VMsafe CPU/memory APIs";
	$resolution = "Please refer to HOST doc for further details";
	@supportedCheckLevel = qw(enterprise);
        @supportedApiVer = qw(4.0.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#HMT11
        $success = 2;
        $code = "HMT11";
        $desc = "Prevent unintended use of VMsafe CPU/memory APIs";
        $resolution = "Please refer to HOST doc for further details";
	@supportedCheckLevel = qw(enterprise);
        @supportedApiVer = qw(4.0.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#HMT12
        $success = 2;
        $desc = "Prevent unintended use of VMsafe network APIs";
        $resolution = "Please refer to HOST doc for further details";
	if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
		$code = "verify-dvfilter-bind";
	} else {
		$code = "HMT12";
	}
	@supportedCheckLevel = qw(enterprise profile1 profile2);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
	}

	#HMT15
        $success = 2;
	$desc = "Verify no unauthorized kernel modules are loaded on the host";
	$resolution = "Please refer to HOST doc for further details";
	if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
		$code = "verify-kernel-modules";
	} else {
        	$code = "HMT15";
	}
	@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#HMT20
        $success = 2;
	if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
		$code = "set-password-complexity";
	} else {
        	$code = "HMT20";
	}
	$desc = "Establish a password policy for password complexity";
        $resolution = "Please refer to HOST doc for further details";
	@supportedCheckLevel = qw(dmz profile1 profile2 profile3);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	$success = 2;
        $code = "verify-admin-group";
	$desc = "Verify Active Directory ESX Admin group membership";
        $resolution = "Please refer to HOST doc for further details";
        @supportedCheckLevel = qw(dmz profile1 profile2 profile3);
        @supportedApiVer = qw(5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	$success = 2;
        $code = "vpxuser-password-age";
        $desc = "Ensure that vpxuser auto-password change meets policy";
        $resolution = "Please refer to HOST doc for further details";
	@supportedCheckLevel = qw(profile1 profile2 profile3);
        @supportedApiVer = qw(5.0.0 5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
               	&log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#HMT21
        $success = 2;
	if($host_api eq "5.0.0") {
                $code = "vpxuser-password-length";
	} else {
        	$code = "HMT21";
	}
        $desc = "Ensure that vpxuser password meets length policy";
        $resolution = "Please refer to HOST doc for further details";
	@supportedCheckLevel = qw(dmz profile1 profile2 profile3);
        @supportedApiVer = qw(4.0.0 4.1.0 5.0.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#HCN01
	if($product eq "embeddedEsx") {
	        $success = 2;
        	$code = "HCN01";
		$desc = "Ensure only authorized users have access to the DCUI";
		$resolution = "Check the users in the local group named localadmin";
		@supportedCheckLevel = qw(enterprise);
        	@supportedApiVer = qw(4.0.0 4.1.0);
        	if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
			&log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
		}
	}

	#HCN02
	#FIX
	if($product eq "embeddedEsx") {
		$success = 2;
		$desc = "Enable Lockdown Mode to restrict root access";
                $resolution = "Lockdown mode is not enabled";
		if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
			$code = "enable-lockdown-mode";
		} else {
			$code = "HCN02";
		}
		@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
        	@supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        	if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
			if($host_view->summary->managementServerIp) {
				if(!defined($host_view->config->adminDisabled)) {
					$resolution = "Lockdown mode can only be checked when executing against vCenter";
				} else {
					if(!$host_view->config->adminDisabled) {
						$success = 0;
					} else {
						$success = 1;
						$resolution = "N/A";
					}
				}
			}
			&log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
		}
	}

	#HCN03
	$success = 2;
	$code = "HCN03";
	$desc = "Avoid adding the root user to local groups";
	$resolution = "Please refer to HOST doc for further details";
	@supportedCheckLevel = qw(enterprise);
        @supportedApiVer = qw(4.0.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
		&log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
	}

	#HCN04
	if($product eq "embeddedEsx") {
		$success = 1;
		$code = "HCN04";
		$desc = "Disable Tech Support Mode";
		$resolution = "Tech Support Mode should be disabled";
	        $req_check_level = "sslf";
		@supportedApiVer = qw(4.0.0);
	        if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
			my $advOpt = Vim::get_view(mo_ref => $host_view->configManager->advancedOption);
			my $results;
			eval {
				$results = $advOpt->QueryOptions(name => 'VMkernel.Boot.techSupportMode');
				foreach(@$results) {
					if($_->value eq 'true') {
        			                $success = 0;
					}
                		}
			};
			if($@) {
				$success = 0;
			}
			if($success eq 1) {
	                        $resolution = "N/A";
        	        }
			&log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
		}
	}

	if($product eq "embeddedEsx") {
                $success = 1;
                $code = "disable-esxi-shell";
                $desc = "Disable ESXi Shell unless needed for diagnostics or troubleshooting";
                $resolution = "Please refer to HOST doc for further details";
		@supportedCheckLevel = qw(profile1 profile2 profile3);
        	@supportedApiVer = qw(5.0.0 5.1.0);
        	if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                        my $serviceSys = Vim::get_view(mo_ref => $host_view->configManager->serviceSystem);
                        $services = $serviceSys->serviceInfo->service;
                        foreach(@$services) {
                                if($_->key eq 'TSM') {
                                        if($_->running) {
                                                $success = 0;
                                        }
                                }
                        }
                        &log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
                }
        }

	if($product eq "embeddedEsx") {
                $success = 1;
                $code = "disable-ssh";
                $desc = "Disable SSH";
                $resolution = "Please refer to HOST doc for further details";
		@supportedCheckLevel = qw(profile1 profile2 profile3);
        	@supportedApiVer = qw(5.0.0 5.1.0);
        	if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                        my $serviceSys = Vim::get_view(mo_ref => $host_view->configManager->serviceSystem);
                        $services = $serviceSys->serviceInfo->service;
                        foreach(@$services) {
                                if($_->key eq 'TSM-SSH') {
                                        if($_->running) {
                                                $success = 0;
                                        }
                                }
                        }
                        &log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
                }
        }

	#HCN05
	if($product eq "embeddedEsx") {
	        $success = 1;
		$desc = "Disable DCUI to prevent all local administrative control";
                $resolution = "Please refer to HOST doc for further details";
		if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
			$code = "disable-dcui";
		} else {
        		$code = "HCN05";
		}
		@supportedCheckLevel = qw(sslf profile1);
        	@supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        	if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
			my $serviceSys = Vim::get_view(mo_ref => $host_view->configManager->serviceSystem);
                        $services = $serviceSys->serviceInfo->service;
                        foreach(@$services) {
                                if($_->key eq 'DCUI') {
                                        if($_->running) {
                                                $success = 0;
                                        }
                                }
                        }
        	        &log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
        	}
	}

	#HCN06
	if($product eq "embeddedEsx") {
	        $success = 1;
        	$code = "HCN06";
	        $desc = "Disable Tech Support Mode unless needed for diagnostics and break-fix";
        	$resolution = "Please refer to HOST doc for further details";
		@supportedCheckLevel = qw(sslf);
        	@supportedApiVer = qw(4.1.0);
        	if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                        my $serviceSys = Vim::get_view(mo_ref => $host_view->configManager->serviceSystem);
                        $services = $serviceSys->serviceInfo->service;
                        foreach(@$services) {
                                if($_->key eq 'TSM') {
                                        if($_->running) {
                                                $success = 0;
                                        }
                                }
                        }
                        &log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
                }
	}

	#HCN07
	if($product eq "embeddedEsx") {
		$success = 1;
		$desc = "Set a timeout for the ESXi Shell to automatically disabled idle sessions after a predetermined period";
		if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
			$code = "set-shell-timeout";
			$resolution = "Set UserVars.ESXiShellTimeOut > 0";
		} else {
 	       		$code = "HCN07";
	        	$resolution = "Set UserVars.TSMTimeOut > 0";
		}
		@supportedCheckLevel = qw(enterprise profile1 profile2 profile3);
       	 	@supportedApiVer = qw(4.0.0 4.1.0 5.0.0 5.1.0);
        	if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                        my $advOpt = Vim::get_view(mo_ref => $host_view->configManager->advancedOption);
                        my $results;
                        eval {
				if($host_api eq "5.0.0" || $host_api eq "5.1.0") {
					$results = $advOpt->QueryOptions(name => 'UserVars.ESXiShellTimeout');
				} else {
                                	$results = $advOpt->QueryOptions(name => 'UserVars.TSMTimeOut');
				}
                                foreach(@$results) {
                                        if($_->value eq 0) {
                                                $success = 0;
					}
                                }
                        };
                        if($@) {
                                $success = 0;
                        }
			if($success eq 1) {
                        	$resolution = "N/A";
                	}
                	&log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
                }
	}

	if($product eq "embeddedEsx") {
		$success = 1;
		$code = "set-shell-interactive-timeout";
		$desc = "Set a timeout to automatically terminate idle ESXi Shell and SSH sessions";
		$resolution = "Set UserVars.ESXiShellInteractiveTimeout > 0";
		@supportedCheckLevel = qw(profile1 profile2 profile3);
		@supportedApiVer = qw(5.1.0);
		if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
			my $advOpt = Vim::get_view(mo_ref => $host_view->configManager->advancedOption);
			my $results;
			eval {
				$results = $advOpt->QueryOptions(name => 'UserVars.ESXiShellInteractiveTimeout');
				foreach(@$results) {
					if($_->value eq 0) {
						$success = 0;
					}
				}
			};
			if($@) {
				$success = 0;
			}
			if($success eq 1) {
				$resolution = "N/A";
			}	
			&log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
		}
	}

	if($product eq "embeddedEsx") {
                $success = 1;
                $code = "enable-bpdu-filter";
                $desc = "Enable BPDU filter on the ESXi host to prevent being locked out of physical switch ports with Portfast and BPDU Guard enabled";
                $resolution = "Set Net.BlockGuestBPDU to 1";
                @supportedCheckLevel = qw(profile1 profile2 profile3);
                @supportedApiVer = qw(5.1.0);
                if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                        my $advOpt = Vim::get_view(mo_ref => $host_view->configManager->advancedOption);
                        my $results;
                        eval {
                                $results = $advOpt->QueryOptions(name => 'Net.BlockGuestBPDU');
                                foreach(@$results) {
                                        if($_->value eq 1) {
                                                $success = 0;
                                        }
                                }
                        };
                        if($@) {
                                $success = 0;
                        }
                        if($success eq 1) {
                                $resolution = "N/A";
                        }
                        &log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
                }
        }

        $success = 2;
        $code = "create-local-admin";
        $desc = "Create a non-root user account for local admin access";
        $resolution = "Please refer to HOST doc for further details";
        @supportedCheckLevel = qw(profile1 profile2 profile3);
        @supportedApiVer = qw(5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

        $success = 2;
        $code = "set-dcui-access";
        $desc = "Set DCUI.Access to allow trusted users to  override lockdown mode";
        $resolution = "Please refer to HOST doc for further details";
        @supportedCheckLevel = qw(profile1 profile2 profile3);
        @supportedApiVer = qw(5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

        $success = 2;
        $code = "enable-remote-dump";
        $desc = "Configure a centralized location to collect ESXi host core dumps";
        $resolution = "Please refer to HOST doc for further details";
        @supportedCheckLevel = qw(profile1 profile2 profile3);
        @supportedApiVer = qw(5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

        $success = 2;
        $code = "enable-host-profiles";
        $desc = "Configure Host Profiles to monitor and alert on configuration changes";
        $resolution = "Please refer to HOST doc for further details";
        @supportedCheckLevel = qw(profile1 profile2 profile3);
        @supportedApiVer = qw(5.1.0);
        if(&checkRequestCheck(\@supportedCheckLevel,$check_level) && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("HOST",$hostname,$code,$desc,$success,"N/A",$resolution);
        }
}

sub COSReport {
	my ($host_view,$product,$folder,$hostname,$host_username,$host_password,$check_level,$host_api) = @_;

	my ($code,$success,$desc,$resolution,$req_check_level,@supportedApiVer);
	
	#CON01
	$success = 1;
	$code = "CON01";
	$desc = "Ensure ESX Firewall is configured to High Security";
	$req_check_level = "enterprise";
	@supportedApiVer = qw(4.0.0 4.1.0);
        if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
	        if($host_view->config->firewall) {
			if(!$host_view->config->firewall->defaultPolicy->incomingBlocked) {
				$success = 0;
				$resolution = "esxcfg-firewall --blockIncoming";
                	}
			
			if(!$host_view->config->firewall->defaultPolicy->outgoingBlocked) {
                                $success = 0;
				$resolution = "esxcfg-firewall --blockOutgoing";
                        }
	        } else {
			$success = 0;
			$resolution = "Firewall should not be disable";
        	}
		if($success eq 1) {
			$resolution = "N/A";
		}
		&log("COS",$hostname,$code,$desc,$success,"esxcfg-firewall --blockIncoming<br>esxcfg-firewall --blockOutgoing",$resolution);
	}

	#CON02
	$success = 2;
        $code = "CON02";
	$desc = "Limit network access to applications and services";
	$resolution = "esxcfg-firewall --query to query for running services";
	$req_check_level = "enterprise";
	@supportedApiVer = qw(4.0.0 4.1.0);
        if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
        	&log("COS",$hostname,$code,$desc,$success,"N/A",$resolution);
	}

	#CON03
        $success = 2;
        $code = "CON03";
        $desc = "Do not run NFS or NIS clients in the service console";
        $resolution = "Please refer to the HOST doc for further details";
        $req_check_level = "enterprise";
	@supportedApiVer = qw(4.0.0 4.1.0);
        if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("COS",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#COM01
	$success = 2;
        $code = "COM01";
	$desc = "Do not apply Red Hat patches to the Service Console";
	$resolution = "Apply only patches published by VMware & follow <a href=\"http://www.vmware.com/security\">http://www.vmware.com/security</a>";
	$req_check_level = "enterprise";
	@supportedApiVer = qw(4.0.0 4.1.0);
        if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("COS",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#COM02
	$success = 2;
        $code = "COM02";
	$desc = "Do not rely upon tools that only check for Red Hat patches";
	$resolution = "Use scanners specifically for ESX Service Console (COS)";
	$req_check_level = "enterprise";
	@supportedApiVer = qw(4.0.0 4.1.0);
        if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("COS",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#COM03
	$success = 2;
        $code = "COM03";
	$desc = "Do Not Manage the Service Console as a Red Hat Linux Host";
	$resolution = "Manage Service Console with only vmkfstools & esxcfg-* commands";
	$req_check_level = "enterprise";
	@supportedApiVer = qw(4.0.0 4.1.0);
        if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("COS",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#COM04
	$success = 2;
        $code = "COM04";
	$desc = "Use vSphere Client and vCenter to Administer the Hosts Instead of Service Console";
	$resolution = "Use vSphere APIs whenever possible for security policies & processes";
	$req_check_level = "enterprise";
	@supportedApiVer = qw(4.0.0 4.1.0);
        if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("COS",$hostname,$code,$desc,$success,"N/A",$resolution);
        }
	
	#COP01
	$success = 2;
        $code = "COP01";
	$desc = "Use a Directory Service for Authentication";
	$resolution = "esxcfg-auth to configure directory services - <a href=\"http://www.vmware.com/vmtn/resources/582\">http://www.vmware.com/vmtn/resources/582</a>";
	$req_check_level = "enterprise";
	@supportedApiVer = qw(4.0.0 4.1.0);
        if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("COS",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#COP02
	$success = 2;
        $code = "COP02";
	$desc = "Establish a Password Policy for Password Complexity";
	$resolution = "Use esxcfgauth --usepamqc to configure password complexity";
	$req_check_level = "dmz";
	@supportedApiVer = qw(4.0.0 4.1.0);
        if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("COS",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#COP03
	$success = 2;
        $code = "COP03";
	$desc = "Establish a Password Policy for Password History";
	$resolution = "Please refer to COS document for detail instructions";
	$req_check_level = "dmz";
	@supportedApiVer = qw(4.0.0 4.1.0);
        if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("COS",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#COP04
	$success = 2;
        $code = "COP04";
	$desc = "Establish a Maximum Password Aging Policy";	
	$resolution = "Use esxcfgauth --passmaxdays=n to set max password age";
	$req_check_level = "dmz";
	@supportedApiVer = qw(4.0.0 4.1.0);
        if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("COS",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#COP05
	$success = 2;
        $code = "COP05";
	$desc = "Establish a Password Policy for Minimum Days Before a Password is Changed";
	$resolution = "Use esxcfgauth --passmindays=n to check min password life setting";
	$req_check_level = "dmz";
	@supportedApiVer = qw(4.0.0 4.1.0);
        if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("COS",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#COP06
	$success = 2;
        $code = "COP06";
	$desc = "Ensure that vpxuser auto-password change in vCenter meets policy";
	$resolution = "Configure vCenter Adv Config: vCenterVirtualCenter.VimPasswordExpirationInDays";
	$req_check_level = "dmz";
	@supportedApiVer = qw(4.0.0);
        if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("COS",$hostname,$code,$desc,$success,"N/A",$resolution);
        }
	
	#COL01
	$success = 2;
        $code = "COL01";
	$desc = "Configure syslog logging";
	$resolution = "Please refer to COS document for detail instructions";
	$req_check_level = "enterprise";
	@supportedApiVer = qw(4.0.0 4.1.0);
        if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("COS",$hostname,$code,$desc,$success,"N/A",$resolution);
        }
	
	#COL02
	$success = 2;
	$code = "COL02";
	$desc = "Configure NTP time synchronization";
	$resolution = "Please refer to COS document for detail instructions";
        $req_check_level = "enterprise";
	@supportedApiVer = qw(4.0.0 4.1.0);
        if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("COS",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#COH01
	$success = 2;
        $code = "COH01";
	$desc = "Partition the disk to prevent the root file system from filling up";	
	$resolution = "Please refer to <a href=\"http://pubs.vmware.com/vsp40u1/install/c_esx_partitioning.html#1_9_18_1\">http://pubs.vmware.com/vsp40u1/install/c_esx_partitioning.html#1_9_18_1</a>";
	$req_check_level = "enterprise";
	@supportedApiVer = qw(4.0.0 4.1.0);
        if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("COS",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#COH03
	$success = 2;
        $code = "COH03";
	$desc = "Establish and Maintain File System Integrity";
	$resolution = "Configuration files should be monitored with something like Tripwire for file intergrity";
	$req_check_level = "dmz";
	@supportedApiVer = qw(4.0.0 4.1.0);
        if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("COS",$hostname,$code,$desc,$success,"N/A",$resolution);
        }
	
	#COH04
	$success = 2;
        $code = "COH04";
	$desc = "Ensure permissions of important files and utility commands have notbeen changed from default";
	$resolution = "Please refer to <a href=\"http://pubs.vmware.com/vsp40u1/server_config/r_default_setuid_applications.html\">http://pubs.vmware.com/vsp40u1/server_config/r_default_setuid_applications.html</a>";
	$req_check_level = "dmz";
	@supportedApiVer = qw(4.0.0 4.1.0);
        if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("COS",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#COA01
	$success = 2;
        $code = "COA01";
	$desc = "Prevent tampering at boot time";
	$resolution = "During the ESX installation, the Advanced option allows you to set a grub password";
	$req_check_level = "dmz";
	@supportedApiVer = qw(4.0.0 4.1.0);
        if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("COS",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#COA02
	$success = 2;
        $code = "COA02";
	$desc = "Require Authentication for Single User Mode";
	$resolution = "Add line \"~~:S:wait:/sbin/sulogin\" to /etc/inittab";
	$req_check_level = "sslf";
	@supportedApiVer = qw(4.0.0 4.1.0);
        if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("COS",$hostname,$code,$desc,$success,"N/A",$resolution);
        }	

	#COA03
	$success = 2;
        $code = "COA03";
	$desc = "Ensure root access via SSH is disabled";
	$resolution = "\"PermitRootLogin\" in the /etc/sshd_conf should be setto \"no\"";
	$req_check_level = "enterprise";
	@supportedApiVer = qw(4.0.0 4.1.0);
        if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("COS",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#COA04
        $success = 2;
        $code = "COA04";
	$desc = "Disallow Direct root Login";	
	$resolution = "cat /dev/null > /etc/securetty";
	$req_check_level = "sslf";
	@supportedApiVer = qw(4.0.0 4.1.0);
        if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("COS",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#COA05
	$success = 2;
        $code = "COA05";
	$desc = "Limit access to the su command";
	$resolution = "Configure PAM module /etc/pam.d/su";
	$req_check_level = "enterprise";
	@supportedApiVer = qw(4.0.0 4.1.0);
        if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("COS",$hostname,$code,$desc,$success,"N/A",$resolution);
        }

	#COA06	
	$success = 2;
        $code = "COA06";
	$desc = "Configure and use sudo to control administrative access";	
	$resolution = "Ensure access to commands are controled and configured properly in /etc/sudoers";
	$req_check_level = "enterprise";
	@supportedApiVer = qw(4.0.0 4.1.0);
        if($req_check_level eq $check_level && &checkApiVersion(\@supportedApiVer,$host_api)) {
                &log("COS",$hostname,$code,$desc,$success,"N/A",$resolution);
        }
}

sub getAllAdvParams {
	my ($vm_view) = @_;

	my $extraConf = $vm_view->config->extraConfig;

	#caputure all VM advanced params
        foreach(@$extraConf) {
		my $vm_key = lc($_->key);
                my $vm_value = lc($_->value);
		$vms_all_adv_params{$vm_key} = $_->value;
	}
}

sub queryVMAdvConfiguration {
	my ($vm_view,$vm_name,$params,$code,$descr,$resolution,$checklevel,$reqlevel) = @_;
	my %configs = %$params;

	my $success = 1;

	if($checklevel eq $reqlevel) {
		my %foundParams = ();
		for my $key ( keys %configs ) {
			my $value = $configs{$key};
			my $lckey = lc($key);
			my $lcvalue = lc($value);
			if(exists $vms_all_adv_params{$lckey}) {
				if(lc($vms_all_adv_params{$lckey}) !~ m/$lcvalue/) {
					$resolution = "param exists but is configured incorrectly";
					$success = 0;
					$foundParams{$lckey} = "incorrect";
				} else {
					$resolution = "N/A";
					$foundParams{$lckey} = "yes"
				}
			} else {
				$resolution = $lckey . " needs to be configured";
				$success = 0;
				$foundParams{$lckey} = "no";
			}
			my $parameter_check = $lckey . "=" . $lcvalue;
			&log("VM",$vm_name,$code,$descr,$success,$parameter_check,$resolution);
    		}
	}
}

sub checkDevice {
	my ($devices,$vm_name,$param,$code,$descr,$resolution,$checklevel,$reqlevel) = @_;

	my $success = 1;
	$resolution = "N/A";

	foreach(@$devices) {
		if($_->isa($param)) {
			my $label = eval {$_->deviceInfo->label} || "";
			next if ($param eq "VirtualIDEController" && $label eq "IDE 0");
			$success = 0;
			$resolution = "VM contains " . $param;
			if($param eq "VirtualIDEController" && !defined($_->device)) {
				$success = 1;
				$resolution = "N/A";
                        }
			&log("VM",$vm_name,$code,$descr,$success,$param,$resolution);
			return; 
		}
	}
	&log("VM",$vm_name,$code,$descr,$success,$param,$resolution);
}

sub validateEndPoint {
	my ($hostname,$ep) = @_;
	
	my $success = 0;

	my $service = Vim::get_vim_service();
        my $service_url = URI::URL->new($service->{vim_soap}->{url});
        my $user_agent = $service->{vim_soap}->{user_agent};
        $service_url =~ s/sdk//g;
        $service_url =~ s/\/webService//g;
        my $url = $service_url . $ep;

	my $request = HTTP::Request->new("GET", $url);
	my $response = $user_agent->request($request);
	if($response) {
		if($response->code ne "404") {
			$success = 1;
		}
	} else {
                $success = 2;
        }
	return $success;
}

sub downloadFile {
	my ($mode,$src_file,$dst_file,$entity,$hostname,$code,$desc) = @_;

	my $success = 1;
	my $resolution;
	my $service = Vim::get_vim_service();
	my $service_url = URI::URL->new($service->{vim_soap}->{url});
	my $user_agent = $service->{vim_soap}->{user_agent};	
	$service_url =~ s/sdk//g;
	$service_url =~ s/\/webService//g;
	my $url = $service_url . $mode . "/" . $src_file;

	my $request = HTTP::Request->new("GET", $url);
	my $response = $user_agent->request($request, $dst_file);
	if ($response) {
        	if(!$response->is_success) {
			$success = 0;
			$resolution = "Download of $src_file was unsuccessful";
			&log($entity,$hostname,$code,$desc,$success,$resolution);
         	}
      	} else {
		$success = 0;
                $resolution = "Unable to download $src_file";
      		&log($entity,$hostname,$code,$desc,$success,$resolution);
	}
}

sub createBackupDirectory {
        my ($dir) = @_;

        `mkdir -p $dir`
}

sub sendMail {
        my $smtp = Net::SMTP->new($EMAIL_HOST ,Hello => $EMAIL_DOMAIN, Timeout => 30,);

        unless($smtp) {
                die "Error: Unable to setup connection with email server: \"" . $EMAIL_HOST . "\"!\n";
        }

	open(DATA, $reportname) || die("Could not open the file");
	my @report1 = <DATA>;
        close(DATA);

	my @report2 = ();
	if($csv eq 'yes') {
		open(DATA, $csvReportName) || die("Could not open the file");
	        @report2 = <DATA>;
        	close(DATA);
	}

	my $boundary = 'frontier';

	$smtp->mail($EMAIL_FROM);
	$smtp->to($EMAIL_TO);
	$smtp->data();
	$smtp->datasend('From: '.$EMAIL_FROM."\n");
	$smtp->datasend('To: '.$EMAIL_TO."\n");
	$smtp->datasend("Subject: VMware vSphere Security Hardening Guide Check Completed\n");
	$smtp->datasend("MIME-Version: 1.0\n");
	$smtp->datasend("Content-type: multipart/mixed;\n\tboundary=\"$boundary\"\n");
	$smtp->datasend("\n");
	$smtp->datasend("--$boundary\n");
	$smtp->datasend("Content-type: text/plain\n");
	$smtp->datasend("Content-Disposition: quoted-printable\n");
	$smtp->datasend("\nReport $reportname is attached!\n");
	$smtp->datasend("--$boundary\n");
	$smtp->datasend("Content-Type: application/text; name=\"$reportname\"\n");
	$smtp->datasend("Content-Disposition: attachment; filename=\"$reportname\"\n");
	$smtp->datasend("\n");
	$smtp->datasend("@report1\n");
	if($csv eq 'yes') {
		$smtp->datasend("--$boundary\n");
		$smtp->datasend("Content-type: text/plain\n");
		$smtp->datasend("Content-Disposition: quoted-printable\n");
                $smtp->datasend("Content-Type: application/text; name=\"$csvReportName\"\n");
                $smtp->datasend("Content-Disposition: attachment; filename=\"$csvReportName\"\n");
		$smtp->datasend("\n");
		$smtp->datasend("@report2\n");
        }
	$smtp->datasend("--$boundary--\n");
	$smtp->dataend();
        $smtp->quit;
}

# restrict the number of digits after the decimal point
#http://guymal.com/mycode/perl_restrict_digits.shtml
sub restrict_num_decimal_digits {
        my $num=shift;#the number to work on
        my $digs_to_cut=shift;# the number of digits after

        if ($num=~/\d+\.(\d){$digs_to_cut,}/) {
                $num=sprintf("%.".($digs_to_cut-1)."f", $num);
        }
        return $num;
}

sub startReportCreation {
	my ($api) = @_;

	$start_time = time();

	print "Generating $report_name \"$reportname\" ...\n\n";
	print "This can take a few minutes depending on environment size. \nGet a cup of coffee/tea and check out http://www.virtuallyghetto.com\n\n";
	open(REPORT_OUTPUT, ">$reportname");
	
	my $date = " --- Date: ".giveMeDate('MDYHMS');
	my $html_start = <<HTML_START;
<html>
<title>$report_name</title>
<META NAME="AUTHOR" CONTENT="William Lam">

<style type='text/css'>
a:link { color: blue; }
a:visited { color: blue; }
a:hover { color: blue; }
a:active { color: blue; }
.headerCell { 
	background-color: #39516B;
	color: white;
	font-size: small;
	font-variant: small-caps;
	font-family: arial;
	text-align: center;
}
.evenCell { 
	background-color: #E0E0E0;
	color: black;
	font-size: small;
	font-family: arial;
	text-align: left;
}
.oddCell { 
	background-color: #C0C0C0;
	color: black;
	font-size: small;
	font-family: arial;
	text-align: left;
}
.fail { 
	background-color: #FF0000;
	color: black;
	font-size: small;
	font-family: arial;
	text-align: left;
}
.pass { 
	background-color: #66FF99;
	color: black;
	font-size: small;
	font-family: arial;
	text-align: left;
}
.manual { 
	background-color: #99FFFF;
	color: black;
	font-size: small;
	font-family: arial;
	text-align: left;
}
.wip {
	background-color: #666699;
	color: black;
	font-size: small;
	font-family: arial;
	text-align: left;
}
.grade {
	color: red;
	font-size: +45;
	font-weight: 900;
	font-family: arial;
	text-align: left;
}
.body {
	font-family: arial;
}
</style>

<h2>$report_name $date</h2>
HTML_START

if($api eq "4.0") {
	$html_start .= <<HTML_START
Report based on: <a href="http://www.vmware.com/resources/techresources/10109" target="_blank">VMware vSphere 4.0 Security Hardening Guide</a>
<br/><br/>
HTML_START
} elsif($api eq "4.1") {
	$html_start .= <<HTML_START
Report based on: <a href="http://www.vmware.com/resources/techresources/10198" target="_blank">VMware vSphere 4.1 Security Hardening Guide</a>
<br/><br/>
HTML_START
} elsif($api eq "5.0") {
        $html_start .= <<HTML_START
Report based on: <a href="http://communities.vmware.com/docs/DOC-19605" target="_blank">VMware vSphere 5.0 Security Hardening Guide</a>
<br/><br/>
HTML_START
}
	print REPORT_OUTPUT $html_start;
}

sub endReportCreation {
	my $html_end = <<HTML_END;
</html>
<br><hr>
<center>Author: <b><a href="http://www.linkedin.com/in/lamwilliam">William Lam</a></b></center>
<center> <b><a href="http://www.virtuallyghetto.com/">http://www.virtuallyghetto.com</a></b></center>
<center>Generated using: <b><a href="http://communities.vmware.com/docs/DOC-11901">vmwarevSphereSecurityHardeningReportCheck.pl</a></b></center>
<center>Support us by donating <b><a href="http://www.virtuallyghetto.com/p/how-you-can-help.html">here</a></b></center>
<center>Primp Industries&#0153;</center>
HTML_END
	print REPORT_OUTPUT $html_end;
	close(REPORT_OUTPUT);

	$end_time = time();
        $run_time = $end_time - $start_time;
        print "\nStart Time: ",&formatTime(str => scalar localtime($start_time)),"\n";
        print "End   Time: ",&formatTime(str => scalar localtime($end_time)),"\n";

        if ($run_time < 60) {
                print "Duration  : ",$run_time," Seconds\n\n";
        }
        else {
                print "Duration  : ",&restrict_num_decimal_digits($run_time/60,2)," Minutes\n\n";
        }
}

#http://www.infocopter.com/perl/format-time.html
sub formatTime(%) {
        my %args = @_;
        $args{'str'} ||= ''; # e.g. Mon Jul 3 12:59:28 2006

        my @elems = ();
        foreach (split / /, $args{'str'}) {
                next unless $_;
                push(@elems, $_);
        }

        my ($weekday, $month, $mday, $time, $yyyy) = split / /, join(' ', @elems);

        my %months = (  Jan => 1, Feb => 2, Mar => 3, Apr =>  4, May =>  5, Jun =>  6,
                        Jul => 7, Aug => 8, Sep => 9, Oct => 10, Nov => 11, Dec => 12 );

        my $s  = substr($time, 6,2);
        my $m  = substr($time, 3,2);
        my $h  = substr($time, 0, 2);
        my $dd = sprintf('%02d', $mday);

        my $mm_num = sprintf('%02d', $months{$month});

        my $formatted = "$mm_num\-$dd\-$yyyy $h:$m:$s";
        #my $formatted = "$yyyy$mm_num$dd$h$m$s";

        $formatted;
}

sub giveMeDate {
        my ($date_format) = @_;
        my %dttime = ();
	my $my_time;
        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);

        ### begin_: initialize DateTime number formats
        $dttime{year }  = sprintf "%04d",($year + 1900);  ## four digits to specify the year
        $dttime{mon  }  = sprintf "%02d",($mon + 1);      ## zeropad months
        $dttime{mday }  = sprintf "%02d",$mday;           ## zeropad day of the month
        $dttime{wday }  = sprintf "%02d",$wday + 1;       ## zeropad day of week; sunday = 1;
        $dttime{yday }  = sprintf "%02d",$yday;           ## zeropad nth day of the year
        $dttime{hour }  = sprintf "%02d",$hour;           ## zeropad hour
        $dttime{min  }  = sprintf "%02d",$min;            ## zeropad minutes
        $dttime{sec  }  = sprintf "%02d",$sec;            ## zeropad seconds
        $dttime{isdst}  = $isdst;

        if($date_format eq 'MDYHMS') {
                $my_time = "$dttime{mon}-$dttime{mday}-$dttime{year} $dttime{hour}:$dttime{min}:$dttime{sec}";
        }
        elsif ($date_format eq 'YMD') {
                $my_time = "$dttime{year}-$dttime{mon}-$dttime{mday}";
        }
        return $my_time;
}

sub printReport {
	my ($ht) = @_;

	&printGrade();

	for my $code (sort keys %reportOutput) {
		if($code ne "VCENTER" && $ht ne "VirtualCenter" && $code ne "COS" && $ht ne "embeddedEsx" || $ht eq "VirtualCenter") {
			print REPORT_OUTPUT "<a href=\"#" . $code . "\">" . $code . " Report<\/a><br>\n"
		}
	}
	print REPORT_OUTPUT "<br>";

	for my $code (sort keys %reportOutput) {
		my $value = $reportOutput{$code};

		if($value ne "") {
			my ($extra_info,$numOfChecks,$pass_per,$fail_per,$man_per);

			if($code eq 'COS') {
				$numOfChecks = $cos_total;
				$pass_per = $cos_success_count ? (($cos_success_count/$cos_total)*100) : 0;
				$fail_per = $cos_fail_count ? (($cos_fail_count/$cos_total)*100) : 0;
				$man_per = $cos_manual_count ? (($cos_manual_count/$cos_total)*100) : 0;
			}elsif($code eq 'HOST') {
				$numOfChecks = $host_total;
				$pass_per = $host_success_count ? (($host_success_count/$host_total)*100) : 0;
				$fail_per = $host_fail_count ? (($host_fail_count/$host_total)*100) : 0;
				$man_per = $host_manual_count ? (($host_manual_count/$host_total)*100) : 0;
			}elsif($code eq 'VCENTER') {
				$numOfChecks = $vcenter_total;
                                $pass_per = $vcenter_success_count ? (($vcenter_success_count/$vcenter_total)*100) : 0;
				$fail_per = $vcenter_fail_count ? (($vcenter_fail_count/$vcenter_total)*100) : 0;
				$man_per = $vcenter_manual_count ? (($vcenter_manual_count/$vcenter_total)*100) : 0;
			}elsif($code eq 'VNETWORK') {
				$numOfChecks = $vnetwork_total;
				$pass_per = $vnetwork_success_count ? (($vnetwork_success_count/$vnetwork_total)*100) : 0;
				$fail_per = $vnetwork_fail_count ? (($vnetwork_fail_count/$vnetwork_total)*100) : 0;
				$man_per = $vnetwork_manual_count ? (($vnetwork_manual_count/$vnetwork_total)*100) : 0;
			}elsif($code eq 'VM') {
				$numOfChecks = $vm_total;
				$pass_per = $vm_success_count ? (($vm_success_count/$vm_total)*100) : 0;
				$fail_per = $vm_fail_count ? (($vm_fail_count/$vm_total)*100) : 0;
				$man_per = $vm_manual_count ? (($vm_manual_count/$vm_total)*100) : 0;
			}
			$pass_per = &restrict_num_decimal_digits($pass_per,2);
			$fail_per = &restrict_num_decimal_digits($fail_per,2);
			$man_per = &restrict_num_decimal_digits($man_per,2);

			$extra_info .= "<td class=\"oddCell\"/><b>$numOfChecks total checks</b><td class=\"pass\"/><b>PASS - $pass_per %</b><td class=\"fail\"><b>FAIL - $fail_per %</b><td class=\"manual\"><b>REQUIRE MANUAL VALIDATION - $man_per %</b>";

			my $sec_start = <<SEC_START;
<table border="1" bordercolorlight="#000000" bordercolordark="#000000" cellspacing="0" cellpadding="1">
<tr><td class="evenCell"/><b>$code Report Check</b>$extra_info</tr>
</table>
<table width=100% border="1" width="100%" bordercolorlight="#000000" bordercolordark="#000000" cellspacing="0" cellpadding="1"><center>
<tr height=17> <td class='headerCell'/>Entity<td class='headerCell'/>Code<td class='headerCell'/>Description<td class='headerCell'/>Status<td class='headerCell'/>Parameter Check<td class='headerCell'/>Resolution/Fix</tr>

SEC_START

			print REPORT_OUTPUT "<a name=\"" . $code . "\"><\/a>\n";
			print REPORT_OUTPUT $sec_start;
			print REPORT_OUTPUT $value;

			my $sec_end = <<SEC_END;
</table>
<br/>

SEC_END

			print REPORT_OUTPUT $sec_end;
		}
	}

	#CSV output
	if($csv eq 'yes') {
		open(CSV_REPORT_OUTPUT, ">$csvReportName");
		print CSV_REPORT_OUTPUT $csvOutput;
		close(CSV_REPORT_OUTPUT);
	}
}

sub printGrade {
	my $grade_per = 0;	
	my $grade = "";

	my $total_checks = ($cos_total + $host_total + $vcenter_total + $vnetwork_total + $vm_total);
	my $total_manual_checks = ($cos_manual_count + $host_manual_count + $vcenter_manual_count + $vnetwork_manual_count + $vm_manual_count);
	my $total = ($total_checks - $total_manual_checks);

	my $total_pass = ($cos_success_count + $host_success_count + $vcenter_success_count + $vnetwork_success_count + $vm_success_count);

	if($total_pass eq 0) {
		$grade_per = 0;
	} else {
		$grade_per = ceil(($total_pass/$total)*100); 
	}

	if($grade_per >= 0 && $grade_per <= 59) {
		$grade = "F";
	}elsif($grade_per >= 60 && $grade_per <= 69) {
		$grade = "D";
	}elsif($grade_per >= 70 && $grade_per <= 79) {
		$grade = "C";
	}elsif($grade_per >= 80 && $grade_per <= 89) {
		$grade = "B";
	}elsif($grade_per >= 90 && $grade_per <= 100) {
		$grade = "A+";
	}

	my $grade_start = <<GRADE_START;
<table cellspacing="1" cellpadding="1">
<tr><td class="grade">Grade: $grade_per% $grade</td></tr>
</table>
<br/>

GRADE_START

	print REPORT_OUTPUT $grade_start
}

sub log {
        my ($section,$entity_name,$code,$desc,$pass,$pcheck,$msg) = @_;

        #pass
        #0 = fail
        #1 = pass
        #2 = manual check
	#3 = WIP
	
	if($section eq 'COS') {
		$cos_total++;
		if($pass eq 1) {
			$cos_success_count++;
		}elsif($pass eq 0) {
			$cos_fail_count++;
		}elsif($pass eq 2) {
			$cos_manual_count++;
		}
	}elsif($section eq 'HOST') {
		$host_total++;
                if($pass eq 1) {
                        $host_success_count++;
                }elsif($pass eq 0) {
                        $host_fail_count++;
                }elsif($pass eq 2) {
                        $host_manual_count++;
		}
	}elsif($section eq 'VCENTER') {
		$vcenter_total++;
                if($pass eq 1) {
                        $vcenter_success_count++;
                }elsif($pass eq 0) {
                        $vcenter_fail_count++;
                }elsif($pass eq 2) {
                        $vcenter_manual_count++;
                }
	}elsif($section eq 'VNETWORK') {
		$vnetwork_total++;
                if($pass eq 1) {
                        $vnetwork_success_count++;
                }elsif($pass eq 0) {
                        $vnetwork_fail_count++;
                }elsif($pass eq 2) {
                        $vnetwork_manual_count++;
                }
	}elsif($section eq 'VM') {
		$vm_total++;
                if($pass eq 1) {
                        $vm_success_count++;
                }elsif($pass eq 0) {
                        $vm_fail_count++;
                }elsif($pass eq 2) {
                        $vm_manual_count++;
                }
	}

	my $pass_string;
	if($pass eq 0) {
		$pass_string = "<td class='fail'/>FAIL";
	}elsif($pass eq 1) {
		$pass_string = "<td class='pass'/>PASS";
	}elsif($pass eq 2) {
		$pass_string = "<td class='manual'/>MANUAL";
	}elsif($pass eq 3) {
                $pass_string = "<td class='wip'/>WIP";
	}

	my $output_string = "<tr height=17><td class='oddCell'/>".$entity_name."<td class='evenCell'/>".$code."<td class='oddCell'/>".$desc.$pass_string."<td class='oddCell'/>".$pcheck."<td class='evenCell'/>".$msg."\n";

	if($csv eq 'yes') {
		$csvOutput .= $entity_name . "," . $code . "," . $desc  . "," . (($pass) ? "PASS" : "FAIL") . "," . $msg . "\n";
	}
	
	$reportOutput{$section} .= $output_string; 
	if($debug) {
        	print $section . "\t" . $entity_name . "\t" . $code . "\t" . $desc . "\t" . (($pass) ? "PASS" : "FAIL") . "\t" . $msg . "\n";
	}
}

sub checkApiVersion {
	my ($api_vers,$ver) = @_;

	my $return = 0;

	foreach(@$api_vers) {
		if($ver eq $_) {
			$return = 1;
			last;
		} 
	}
	return $return;
}

sub checkRequestCheck {
	my ($supported_checks,$check) = @_;

        my $return = 0;

        foreach(@$supported_checks) {
                if($check eq $_) {
                        $return = 1;
                        last;
                }
        }
        return $return;
}

#http://freecode.com/projects/ssl-cert-check
sub days_between {
	my ($ssl_date,$today_date) = @_;

        my ($y1, $m1, $d1) = split ("-", $ssl_date);
        my ($y2, $m2, $d2) = split ("-", $today_date);

	my $d2j_tmpmonth1 = (12 * $y1 + $m1 - 3);
	my $d2j_tmpmonth2 = (12 * $y2 + $m2 - 3);

	my $d2j_tmpyear1 = ($d2j_tmpmonth1 / 12);
	my $d2j_tmpyear2 = ($d2j_tmpmonth2 / 12);

	my $d2j1 = ( (734 * $d2j_tmpmonth1 + 15) / 24 - 2 * $d2j_tmpyear1 + $d2j_tmpyear1/4 - $d2j_tmpyear1/100 + $d2j_tmpyear1/400 + $d1 + 1721119);
	my $d2j2 = ( (734 * $d2j_tmpmonth2 + 15) / 24 - 2 * $d2j_tmpyear2 + $d2j_tmpyear2/4 - $d2j_tmpyear2/100 + $d2j_tmpyear2/400 + $d2 + 1721119);

	my $diff = int($d2j1) - int($d2j2);

	return abs($diff);		
}

sub getSSLDate {
	my ($ssl_results) = @_;

	my ($ssl_month,$ssl_day,$ssl_year) = split(' ', $ssl_results);

	 my %months = (  Jan => '01', Feb => '02', Mar => '03', Apr => '04', May => '05', Jun => '06',
                        Jul => '07', Aug => '08', Sep => '09', Oct => '10', Nov => '11', Dec => '12' );

	return "$ssl_year-$months{$ssl_month}-$ssl_day";
}

sub validateConnection {
        my ($host_version,$host_license,$host_type) = @_;
        my $service_content = Vim::get_service_content();
        my $licMgr = Vim::get_view(mo_ref => $service_content->licenseManager);

        ########################
        # CHECK HOST VERSION
        ########################
        if(!$service_content->about->version ge $host_version) {
                Util::disconnect();
                print "This script requires your ESX(i) host to be greater than $host_version\n\n";
                exit 1;
        }

        ########################
        # CHECK HOST LICENSE
        ########################
        my $licenses = $licMgr->licenses;
        foreach(@$licenses) {
                if($_->editionKey eq 'esxBasic' && $host_license eq 'licensed') {
                        Util::disconnect();
                        print "This script requires your ESX(i) be licensed, the free version will not allow you to perform any write operations!\n\n";
                        exit 1;
                }
        }

        ########################
        # CHECK HOST TYPE
        ########################
        if($service_content->about->apiType ne $host_type && $host_type ne 'both') {
                Util::disconnect();
                print "This script needs to be executed against $host_type\n\n";
                exit 1
        }

        return ($service_content->about->apiType,$service_content->about->productLineId,$service_content->about->apiVersion);
}
