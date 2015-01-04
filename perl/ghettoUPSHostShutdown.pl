#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://communities.vmware.com/docs/DOC-11902

use strict;
use warnings;
use POSIX qw(ceil floor);
use VMware::VIFPLib;
use Net::SMTP;

######################################################
# List of ESX(i) hosts to exclude
######################################################

my @exclude_hosts = (
"himalaya.primp-industries.com",
"superleggera.primp-industries.com",
"mauna-loa.primp-industries.com",
);

#################
# EMAIL CONF
#################

my $EMAIL_HOST = "emailserver";
my $EMAIL_DOMAIN = "localhost.localdomain";
my $EMAIL_TO = 'William Lam <william@primp-industries.com.com>';
my $EMAIL_FROM = 'ghettoUPSHostShutdown <ghettoUPSHostShutdown@primp-industries.com.com>';

my %opts = (
        host_operation => {
        type => "=s",
        help => "Host Operation to perform [shutdown|standby|autoquery|dryrun]",
        required => 1,
        },
        vm_operation => {
        type => "=s",
        help => "VM Operation to perform [suspend|shutdown|auto]",
        required => 1,
        },
        logoutput => {
        type => "=s",
        help => "UPS Log output",
        required => 0,
        default => "/tmp/ghettoUPSHostShutdown.log",
        },
        loglevel => {
        type => "=s",
        help => "Log level [info|debug]",
        required => 0,
        default => "debug",
        },
        ups_vm => {
        type => "=s",
        help => "UPS Monitoring VM",
        required => 1,
        },
        timeout => {
        type => "=s",
        help => "Timeout value before shutting down all hosts (mintues)",
        required => 1,
        },
        hostfile => {
        type => "=s",
        help => "Manual list out the ESX(i) hosts in which to prioritize the shutdown process",
        required => 0,
        },
        sendmail => {
        type => "=s",
        help => "Email UPS shutdown log [yes|no]",
        required => 0,
	default => 'no',
        },
);

# validate options, and connect to the server
Opts::add_options(%opts);
# validate options, and connect to the server
Opts::parse();
Opts::set_option("passthroughauth", 1);
Opts::validate();

my $vm_operation = Opts::get_option('vm_operation');
my $host_operation = Opts::get_option('host_operation');
my $log_output = Opts::get_option('logoutput');
my $loglevel = Opts::get_option('loglevel');
my $ups_vm_name = Opts::get_option('ups_vm');
my $timeout = Opts::get_option('timeout');
my $hostfile = Opts::get_option('hostfile');
my $sendmail = Opts::get_option('sendmail');

###### PLEASE DO NOT MODIFY PAST THIS LINE ######

# log level
my %log_level=(
        "debug"   => 1,
        "info"    => 2,
        "warn"    => 3,
        "error"   => 4,
        "fatal"   => 5,
);

my $LOGLEVEL = $log_level{$loglevel};

my $viuser = vifplib_perl::CreateVIUserInfo();
my $vifplib = vifplib_perl::CreateVIFPLib();
my @hosts = ();
my %validhosts = ();
my $vma_host_name;
my $recommended_timeout = 0;

#process and get hosts managed by vMA
if($hostfile) {
        &processFile($hostfile);
} else {
        @hosts = VIFPLib::enumerate_targets();
}

$log_output = "&STDOUT";

summaryStart();
getHostsAndVms();
verifyAndShutdownHosts();
summaryEnd();

Util::disconnect();

#######################################
#
#	HELPER FUNCTIONS
#
#######################################

sub sendMail {
	my $smtp = Net::SMTP->new($EMAIL_HOST ,Hello => $EMAIL_DOMAIN,Timeout => 30,);

        unless($smtp) {
                die "Error: Unable to setup connection with email server: \"" . $EMAIL_HOST . "\"!\n";
        }

        open(DATA, $log_output) || die("Could not open the file");
        my @report = <DATA>;
        close(DATA);

        my $boundary = 'frontier';

        $smtp->mail($EMAIL_FROM);
        $smtp->to($EMAIL_TO);
        $smtp->data();
        $smtp->datasend('From: '.$EMAIL_FROM."\n");
        $smtp->datasend('To: '.$EMAIL_TO."\n");
        $smtp->datasend('Subject: ghettoUPSHostShutdown.pl Completed '.giveMeDate('MDYHMS')."\n");
        $smtp->datasend("MIME-Version: 1.0\n");
        $smtp->datasend("Content-type: multipart/mixed;\n\tboundary=\"$boundary\"\n");
        $smtp->datasend("\n");
        $smtp->datasend("--$boundary\n");
        $smtp->datasend("Content-type: text/plain\n");
        $smtp->datasend("Content-Disposition: quoted-printable\n");
        $smtp->datasend("\nReport $log_output is attached!\n");
        $smtp->datasend("--$boundary\n");
        $smtp->datasend("Content-Type: application/text; name=\"$log_output\"\n");
        $smtp->datasend("Content-Disposition: attachment; filename=\"$log_output\"\n");
        $smtp->datasend("\n");
        $smtp->datasend("@report\n");
        $smtp->datasend("--$boundary--\n");
        $smtp->dataend();
        $smtp->quit;

        `/bin/rm -f $log_output`;
}

sub verifyAndShutdownHosts {
	if($host_operation ne 'autoquery') {
		&log("info","Verifying all VMs are either suspended or powered of - TIMEOUT set to: $timeout min\n");
		my $count = 1;

		while($count <= $timeout) {
			my $no_powered_on_vms = 1;
			#foreach my $host (@validhosts) {
			for my $host (keys %validhosts) {
				if($validhosts{$host} eq "yes") {
                                	eval {
						&log("debug", "Login by vi-fastpass to: " . $host);
                                        	VIFPLib::login_by_fastpass($host);
                                        	my $host_view = Vim::find_entity_view(view_type => 'HostSystem');
                                        	my $vms = Vim::get_views(mo_ref_array => $host_view->vm, properties => ['name','runtime.powerState']);
                                        	my $totalVMs = 0;
                                        	my $numOfVMsOn = 0;
                                        	foreach(@$vms) {
                                	        	$totalVMs += 1;
                          	                      	if($_->{'runtime.powerState'}->val eq 'poweredOn' && $_->{'name'} ne $ups_vm_name) {
                                                        	$numOfVMsOn += 1;
                                                	}
                                        	}

						#remove hosts that have no more powered on VMs so they're not checked again
						if($numOfVMsOn eq 0) {
							$validhosts{$host} = "no";
							&log("info","Host: $host has $numOfVMsOn/$totalVMs VMs powered on and is ready!\n");
						} else {
							&log("info","Host: $host has $numOfVMsOn/$totalVMs VMs still powered on!\n");
						}
                                        	Util::disconnect();

						#use this variable to check if all hosts are ready, if so, don't wait for the entire timeout
                                        	if($numOfVMsOn > 0 ) {
                                                	$no_powered_on_vms = 0;
                                        	}
                                	};
                                	if($@) {
                                        	&log("info","Error: Unable to login to host: ". "\"$host\"! Ensure host is being managed by vMA!");
                                	}
				}
                        }
		
                        last if($no_powered_on_vms eq 1);
			last if($host_operation eq 'dryrun');

			if($host_operation ne 'dryrun') {
				&log("info","Count: $count - Sleeping for 60secs...");
                        	sleep 60;
				$no_powered_on_vms = 0;	
			}
			$count += 1;
                }
		&log("info","Verification stage completed!\n");

		&log("info","Putting hosts into \"$host_operation mode\"");
                #foreach my $host (@validhosts) {
		for my $host (keys %validhosts) {
                        if($host ne $vma_host_name) {
                                VIFPLib::login_by_fastpass($host);
                                my $host_view = Vim::find_entity_view(view_type => 'HostSystem');
                                &shutdownOrStandbyHost($host,$host_view);
                                Util::disconnect();
                        }
                }

		&log("info","Finally putting UPS Monitoring VM host into \"$host_operation mode\"");

                if($sendmail eq "yes") {
                        &log("info","Emailing results before taking down $vma_host_name");
                        &sendMail();
                }

                VIFPLib::login_by_fastpass($vma_host_name);
                my $host_view = Vim::find_entity_view(view_type => 'HostSystem');
                &shutdownOrStandbyHost($vma_host_name,$host_view);
                Util::disconnect();		
	}	
}

sub shutdownOrStandbyHost {
        my ($host,$host_view) = @_;

        if($host_operation eq 'standby' && $host_view->capability->standbySupported eq 'true') {
                if($host_operation ne 'dryrun' && $host_operation ne 'autoquery') {
                        eval {
                                $host_view->PowerDownHostToStandBy_Task(timeoutSec => 300) };
                        if($@) {
                                &log("info","ERROR: $@")
                        }
                }
                &log("info","$host is going into standby mode!");
        } else {
                if($host_operation ne 'dryrun' && $host_operation ne 'autoquery') {
                        eval {
                                $host_view->ShutdownHost(force => 1);
                        };
                        if($@) {
                                &log("info","ERROR: $@")
                        }
                }
                &log("info","$host is now shutting down!");
        }
}

sub getHostsAndVms {
	foreach my $host (@hosts) {
                if (! grep( /^$host/,@exclude_hosts ) ) {
                        &log("info","Found host: ". "\"$host\"");
                        &log("debug", "Main: Login by vi-fastpass to: " . $host);

			my $host_type;
                        eval {
                                VIFPLib::login_by_fastpass($host);
                                #validate ESX/ESXi host
                                my $content = Vim::get_service_content();
                                $host_type = $content->about->apiType;
			};
                        if($@) {
                                &log("info","Error: Unable to login to host: ". "\"$host\"! Ensure host is being managed by vMA!\n");
                        } else {
                                if($host_type eq 'HostAgent') {
                                        #push @validhosts, $host;
					$validhosts{$host} = "yes";
                                        my $host_view = Vim::find_entity_view(view_type => 'HostSystem');
                                        if($host_operation eq 'autoquery') {
                                                &autoquery($host_view);
                                        } else {
                                                my $vms = Vim::get_views(mo_ref_array => $host_view->vm);
                                                &log("info","Begin $vm_operation operation on VMs ...");
                                                if($vm_operation eq 'auto') {
                                                        &autoShutdownVMs($host_view);
                                                } else {
                                                       	&shutdownVMs($vms);
                                                }
                                                &log("info","$vm_operation operation complete!");
                                        }
                                } else {
                                        &log("info","Host: " . "\"$host\" is not an ESX(i) host and will be ignored");
                                }
                                &log("debug", "Main: Disconnect from: ". $host . "\n");
                                Util::disconnect();
			}
                }
        }

        if($host_operation eq 'autoquery' && $vm_operation eq 'auto') {
                &log("info","RECOMMENDED_TIMEOUT_VALUE = > " . ceil(($recommended_timeout/60)) . " minutes\n");
        }
}

sub autoquery {
        my ($host) = @_;

        if($vm_operation eq 'auto') {
                my $autoStartMgr = Vim::get_view(mo_ref => $host->configManager->autoStartManager);

                &log("info","AUTOSTART MANAGER INFO");
                &log("info","--------------------------------------");
                &log("info","AUTOSTART_ENABLED = " . ($autoStartMgr->config->defaults->enabled ? "YES" : "NO"));
                &log("info","DEFAULT_STOP_ACTION = " . $autoStartMgr->config->defaults->stopAction);
                my $default_delay = $autoStartMgr->config->defaults->stopDelay;
                &log("info","DEFAULT_STOP_DELAY = " . ceil(($default_delay/60)) . " minute");

                my $totalTimeInSecs = 0;
                my $powerInfo = $autoStartMgr->config->powerInfo;

		if($powerInfo) {
                	foreach( sort {$a->startOrder cmp $b->startOrder} @$powerInfo) {
                        	my $sd = $_->stopDelay;
                        	my $vmname = Vim::get_view(mo_ref => $_->key, properties => ['name']);
                        	my $order = $_->startOrder;
                        	if($sd eq -1) {
                                	$sd = $default_delay;
                        	}
                        	&log("info","VM=".$vmname->{'name'}."\tORDER=".$order."\tDELAY=".ceil(($sd/60))." minute");
                        	$totalTimeInSecs = $totalTimeInSecs + $sd;
                	}
                	&log("info","TOTAL_STOP_DELAY = " . ceil(($totalTimeInSecs/60)) . " minute");
                	&log("info","--------------------------------------");
		}

                $recommended_timeout = $recommended_timeout + $totalTimeInSecs;
        }
}

sub autoShutdownVMs {
        my ($host) = @_;

        my $autoStartMgr = Vim::get_view(mo_ref => $host->configManager->autoStartManager);
	        
	my $vms = Vim::get_views(mo_ref_array => $host->vm);
        foreach my $vm (@$vms) {
               	if($vm->name eq $ups_vm_name) {
                       	&log("debug","Found UPS Monitoring VM: " . $vm->name);
	                my $vma_host_view = Vim::get_view(mo_ref => $vm->runtime->host);
                        $vma_host_name = $vma_host_view->name;
               	}
        }

	if($autoStartMgr->config->defaults->enabled) {
	        &log("info","Issuing AutoStartPowerOff() ...");
        	if($host_operation ne 'dryrun' && $host_operation ne 'autoquery') {
                	$autoStartMgr->AutoStartPowerOff();
	        } else {
			my $powerInfo = $autoStartMgr->config->powerInfo;
			foreach( sort {$a->startOrder cmp $b->startOrder} @$powerInfo) {
				my $vmname = Vim::get_view(mo_ref => $_->key, properties => ['name']);
				my $action;
				if($_->stopAction eq 'SystemDefault') {
					$action = $autoStartMgr->config->defaults->stopAction;
				} else { $action = $_->stopAction; }
				&log("info","Performing " . $action . " operation on " . $vmname->{'name'});
			}
		}
	} else {
		&log("info","Auto start/stop manager is not enabled, VMs will not be powering down!");
	}
}

sub shutdownVMs {
        my ($vms) = @_;
        foreach my $vm (@$vms) {
                my $vmname = $vm->name;
                if($vmname ne $ups_vm_name) {
                        if($vm->runtime->powerState->val eq 'poweredOn') {
                                if($vm_operation eq 'suspend') {
                                        eval {
                                                &log("info","Suspending $vmname ...");
                                                if($host_operation ne 'dryrun' && $host_operation ne 'autoquery') {
                                                        $vm->SuspendVM();
                                                }
                                        };
                                        if($@) {
                                                &log("info","Unable to suspend $vmname!");
                                        }
                                } else {
                                        if(defined($vm->guest) && ($vm->guest->toolsStatus->val eq 'toolsOld' || $vm->guest->toolsStatus->val eq 'toolsOk') ) {
                                                eval {
                                                        &log("info","Shutting down $vmname via VMware Tools...");
                                                        if($host_operation ne 'dryrun' && $host_operation ne 'autoquery') {
                                                                $vm->ShutdownGuest();
                                                        }
                                                };
                                                if($@) {
                                                        &log("info","Unable to shutdown $vmname!");
                                                }
                                        } else {
                                                eval {
                                                        &log("info","Hard Powering off $vmname, no VMware Tools found ...");
                                                        if($host_operation ne 'dryrun' && $host_operation ne 'autoquery') {
                                                                $vm->PowerOffVM();
                                                        }
                                                };
                                                if($@) {
                                                        &log("info","Unable to hard power off $vmname!");
                                                }
                                        }
                                }
                        }
                } else {
                        &log("info","Found UPS Monitoring VM: $vmname");
                        my $vma_host_view = Vim::get_view(mo_ref => $vm->runtime->host);
                        $vma_host_name = $vma_host_view->name;
                }
        }
}

sub summaryStart {
	if($host_operation eq 'dryrun' || $host_operation eq 'autoquery') {
                &log("info","=========== DRYRUN MODE ENABLED ghettoUPSHostShutdown.pl ==========");
        } else {
                &log("info","================ STARTING ghettoUPSHostShutdown.pl ================");
        }

        #log ups_vm
        &log("info","UPS_MONITORING_VM: $ups_vm_name");

        #vm operation
        &log("info","VM_OPERATION: $vm_operation");

        #host operation
        &log("info","HOST_OPERATION: $host_operation");

        #host selection
        if($hostfile) {
                &log("info","HOST_LIST: MANUAL");
        } else {
                &log("info","HOST_LIST: AUTOMATIC");
        }
        &log("info","===================================================================\n");
} 

sub summaryEnd {
	&log("info","");
	if($host_operation eq 'dryrun' || $host_operation eq 'autoquery') {
        	&log("info","=========== DRYRUN MODE COMPLETED ghettoUPSHostShutdown.pl ========\n");
	} else {
        	&log("info","================ COMPLETED ghettoUPSHostShutdown.pl ================\n");
	}
}

sub timeStamp {
        my ($date_format) = @_;
        my %dttime = ();
        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
        my $my_time;
        my $time_string;

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
                $time_string = $my_time." -- ";
        } elsif ($date_format eq 'YMD') {
                $my_time = "$dttime{year}-$dttime{mon}-$dttime{mday}";
                $time_string = $my_time;
        }
        return $time_string;
}

# Subroutine to process the input file
sub processFile {
        my ($vmlist) =  @_;
        my $HANDLE;
        open (HANDLE, $vmlist) or die(timeStamp('MDYHMS'), "ERROR: Can not locate \"$vmlist\" input file!\n");
        my @lines = <HANDLE>;
        my @errorArray;
        my $line_no = 0;

        close(HANDLE);
        foreach my $line (@lines) {
                $line_no++;
                &TrimSpaces($line);

                if($line) {
                        if($line =~ /^\s*:|:\s*$/){
                                print "Error in Parsing File at line: $line_no\n";
                                print "Continuing to the next line\n";
                                next;
                        }
                        my $host = $line;
                        &TrimSpaces($host);
                        push @hosts,$host;
                }
        }
}

sub TrimSpaces {
        foreach (@_) {
                s/^\s+|\s*$//g
        }
}

sub log {
        my($logLevel, $message) = @_;

        open(LOG,">>$log_output");
        if ($LOGLEVEL <= $log_level{$logLevel}) {
                print LOG "\t" . timeStamp('MDYHMS'), " ",$logLevel, ": ", $message,"\n";
        }
        close(LOG);
}

