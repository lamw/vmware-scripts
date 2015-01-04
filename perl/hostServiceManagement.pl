#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://www.virtuallyghetto.com/2010/07/new-way-of-enabling-and-disabling.html

use strict;
use warnings;
use Term::ANSIColor;
use VMware::VIRuntime;
use VMware::VILib;

# define custom options for vm and target host
my %opts = (
   'operation' => {
      type => "=s",
      help => "Operation to perform on ESX(i) host [start|stop|restart|enable|disable|query]",
      required => 1,
   },
   'service' => {
      type => "=s",
      help => "Service name (use query operation to list available services host)",
      required => 0,
   },
   'hostfile' => {
      type => "=s",
      help => "List of hosts to perform the operation on",
      required => 0,
   },
);

$SIG{__DIE__} = sub{Util::disconnect()};

# read and validate command-line parameters 
Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();
my $hosttype = &validateConnection('3.5.0','licensed','both');

my ($host_view,$task_ref,$hostfile,$operation,$service);
my @host_list = ();

$hostfile = Opts::get_option("hostfile");
$service = Opts::get_option("service");
$operation = Opts::get_option("operation");

&checkHosts();

Util::disconnect();

sub checkHosts {
        if($hosttype eq 'VirtualCenter') {
		unless($hostfile) {
                	Util::disconnect();
                        print "Error: When connecting to vCenter, you must specify --hostfile and provide input file of the ESX(i) hosts you would li
ke to check!\n\n";
                        exit 1;
               	}
		&processFile($hostfile);
		foreach my $host_name( @host_list ) {
                        chomp($host_name);

                        $host_view = Vim::find_entity_view(view_type => 'HostSystem', filter => { 'name' => $host_name});
			if($host_view) {
				print color("magenta") . "Host: " . $host_name . " ( " . $host_view->config->product->fullName . " )" . color("reset") . "\n";
                        	&performOperation($host_view,$operation,$service);
                        	print "\n";
			} else {
				print color("red") . "Error: Unable to locate host: $host_name!\n\n";
			}
               }
        } else {
                $host_view = Vim::find_entity_view(view_type => 'HostSystem');
		print color("magenta") . "Host: " . $host_view->name . " ( " . $host_view->config->product->fullName . " )" . color("reset") . "\n";
		&performOperation($host_view,$operation,$service);
		print "\n";
        }
}

sub performOperation {
	my ($host,$op,$service) = @_;

	my $serviceSystem = Vim::get_view(mo_ref => $host->configManager->serviceSystem);

	if($operation eq 'query') {
		my $services = $serviceSystem->serviceInfo->service;
		foreach(@$services) {
			printf(color("yellow")."%-16.16s  %-11.11s  Startup: %3.3s".color("reset")."\n",
			       $_->key, ($_->running ? "RUNNING" : "NOT RUNNING"), $_->policy);
		}
	}elsif($operation eq 'start') {
		unless($service) {	
			Util::disconnect();
			print "Error: \"start\" operation requires --service param!\n";
			exit 1;
		}
	
		my $running = &checkService($serviceSystem,$service);
	
		if($running eq "no") {
			eval {
				print color("yellow") . "Starting $service" . color("reset") . "\n";
				$serviceSystem->StartService(id => $service);
				print "\t" . color("cyan") . "Successfully started $service - [ " . color("green") . "OK" . color("cyan") . " ]\n" . color("reset");
			}; 
			if($@) {
				print "\t" . color("red") . "Error: Unable to start service \"$service\" due to: " . $@ . color("reset") . "\n";
			}
		} else { print "\t" . color("yellow") . "$service is already running!" . color("reset") . "\n"; } 
	}elsif($operation eq 'stop') {
		unless($service) {
                        Util::disconnect();
                        print "Error: \"stop\" operation requires --service param!\n";
                        exit 1;
                }

		my $running = &checkService($serviceSystem,$service);

                if($running eq "yes") {
			eval {
                        	print color("yellow") . "Stopping $service" . color("reset") . "\n";
	                        $serviceSystem->StopService(id => $service);
        	                print "\t" . color("cyan") . "Successfully stopped $service - [ " . color("green") . "OK" . color("cyan") . " ]\n" . color("reset");
                	};
	                if($@) {
        	                print "\t" . color("red") . "Error: Unable to stop service \"$service\" due to: " . $@ . color("reset") . "\n";
                	}
		} else { print "\t" . color("yellow") . "$service is not running!" . color("reset") . "\n"; }
	}elsif($operation eq 'restart') {
		unless($service) {
                        Util::disconnect();
                        print "Error: \"restart\" operation requires --service param!\n";
                        exit 1;
                }
		eval {
                        print color("yellow") . "Restarting $service" . color("reset") . "\n";
                        $serviceSystem->RestartService(id => $service);
                        print "\t" . color("cyan") . "Successfully restarted $service - [ " . color("green") . "OK" . color("cyan") . " ]\n" . color("reset");
                };
                if($@) {
                        print "\t" . color("red") . "Error: Unable to restart service \"$service\" due to: " . $@ . color("reset") . "\n";
                }
	}elsif($operation eq 'enable') {
		unless($service) {
			Util::disconnect();
			print "Error: \"enable\" operation requires --service param!\n";
			exit 1;
		}

		my $policy = &checkServiceEnabled($serviceSystem,$service);
		if($policy eq "off") {
			eval {
				$serviceSystem->UpdateServicePolicy(id => $service, policy => "on");
				print "\t" . color("cyan") . "Successfully enabled $service\n" . color("reset");
			};
			if($@) {
				print "\t" . color("red") . "Error: Unable to change startup policy on service \"$service\" due to: " . $@ . color("reset") . "\n";			}

		}elsif($policy eq "on") {
			print "\t" . color("yellow") . "$service is already enabled" . color("reset") . "\n";
		} else {
			print "\t" . color("red") . "Error: Unknown startup policy \"$policy\"" . color("reset") . "\n";
		}
	}elsif($operation eq 'disable') {
		unless($service) {
			Util::disconnect();
			print "Error: \"disable\" operation requires --service param!\n";
			exit 1;
		}

		my $policy = &checkServiceEnabled($serviceSystem,$service);
		if($policy eq "on") {
			eval {
				$serviceSystem->UpdateServicePolicy(id => $service, policy => "off");
				print "\t" . color("cyan") . "Successfully disabled $service\n" . color("reset");
			};
			if($@) {
				print "\t" . color("red") . "Error: Unable to change startup policy on service \"$service\" due to: " . $@ . color("reset") . "\n";
			}
		}elsif($policy eq "off") {
			print "\t" . color("yellow") . "$service is already disabled" . color("reset") . "\n";
		} else {
			print "\t" . color("red") . "Error: Unknown startup policy \"$policy\"" . color("reset") . "\n";
		}
	} else {
		Util::disconnect();
		print "Error: Invalid operation selection!\n";
		exit 1;
	}		
}

sub checkService {
	my ($serviceSystem,$service) = @_;

	my $services = $serviceSystem->serviceInfo->service;

	foreach(@$services) {
		if($_->key eq $service) {
			if($_->running) {
				return "yes";			
			}	
		}
	}
	return "no";
}

sub checkServiceEnabled {
	my ($serviceSystem,$service) = @_;

	my $services = $serviceSystem->serviceInfo->service;

	foreach(@$services) {
		if($_->key eq $service) {
			return $_->policy;
		}
	}
	return 0;
}

# Subroutine to process the input file
sub processFile {
        my ($vmlist) =  @_;
        my $HANDLE;
        open (HANDLE, $vmlist) or die("ERROR: Can not locate \"$vmlist\" input file!\n");
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
                        push @host_list,$host;
                }
        }
}

sub TrimSpaces {
        foreach (@_) {
                s/^\s+|\s*$//g
        }
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

        return $service_content->about->apiType;
}
