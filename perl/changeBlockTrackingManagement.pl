#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://communities.vmware.com/docs/DOC-11642

use strict;
use warnings;
use Term::ANSIColor;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
   vmfile => {
      type => "=s",
      help => "VM list input file",
      required => 0,
   },
   operation => {
      type => "=s",
      help => "[query|enable|disable]",
      required => 1,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();
my $hosttype = &validateConnection('4.0.0','licensed','both');

my @vmlist = ();
my $vmfile = Opts::get_option('vmfile');
my $operation = Opts::get_option('operation');

if($operation eq 'query') {
	&queryCBT();
}elsif($operation eq 'enable') {
	unless($vmfile) {
		Util::disconnect();
		print color("red") . "Operation \"enable\" requires command line param --vmfile!\n\n" . color("reset");
		exit 1
	}
	processFile($vmfile);
        &enableCBT();
}elsif($operation eq 'disable') {
	unless($vmfile) {
                Util::disconnect();
                print color("red") . "Operation \"disable\" requires command line param --vmfile!\n\n" . color("reset");
		exit 1
        }
	processFile($vmfile);
	&disableCBT();
} else {
	print color("red") . "Invalid operation!\n" . color("reset");
}

Util::disconnect();

sub queryCBT {
        my $vms = Vim::find_entity_views(view_type => 'VirtualMachine');
	
	foreach my $vm(@$vms) {
		#verify VM supports changeTrackingSupported
                if($vm->capability->changeTrackingSupported) {
			if($vm->config->changeTrackingEnabled) {
				print color("green") . "\"" . $vm->name . "\" is CBT enabled\n" . color("reset");
			} else {
				print color("yellow") . "\"" . $vm->name . "\" is NOT CBT enabled\n" . color("reset");
			}
		} else {
			print color("red") . "\"" . $vm->name . "\" does not support CBT, feature only available on HW 7!\n" . color("reset");
		}
	}
}

sub enableCBT {
	for my $vmname(@vmlist) {
	        my $vm = Vim::find_entity_view(view_type => 'VirtualMachine', filter => {"config.name" => $vmname});

		if($vm) {
        	        #verify VM supports changeTrackingSupported
                	if($vm->capability->changeTrackingSupported) {
                        	#verify VM is powered off
	                        if($vm->runtime->powerState->val eq 'poweredOff') {
					if($vm->config->changeTrackingEnabled) {
						print color("yellow") . "\"" . $vm->name . "\" has CBT enabled already\n\n" . color("reset");
					} else {
                                		eval {
                                        		my $spec = VirtualMachineConfigSpec->new(changeTrackingEnabled => 'true');
	                     	                   	print color("yellow") . "Enabling CBT on \"" . $vm->name . "\" ...\n" . color("reset");
        	                	        	my $task = $vm->ReconfigVM_Task(spec => $spec);
                		               	        my $msg = color("green") . "\tSucessfully enabled CBT for \"" . $vm->name . "\"!\n" . color("reset");
                                	       		&getStatus($task,$msg);
                                		};
					}
	                        } else {
        	                        print color("red") . "\"" . $vm->name . "\" is still powered on, VM needs to be powered off before CBT can be enabled!\n\n" . color("reset");
                	        }
 	               } else {
        	                print color("red") . "\"" . $vm->name . "\" does not support CBT, feature only available on HW 7!\n\n" . color("reset");
                	}
	        } else {
                	print color("red") . "Unable to find \"" . $vm->name . "\"!\n\n" . color("reset");
        	}
	}
}

sub disableCBT {
	for my $vmname(@vmlist) {
                my $vm = Vim::find_entity_view(view_type => 'VirtualMachine', filter => {"config.name" => $vmname});
		
		if($vm) {
                        #verify VM supports changeTrackingSupported
                        if($vm->capability->changeTrackingSupported) {
                                #verify VM is powered off
                                if($vm->runtime->powerState->val eq 'poweredOff') {
                                        if(!$vm->config->changeTrackingEnabled) {
                                                print color("yellow") . "\"" . $vm->name . "\" is CBT disabled already\n\n" . color("reset");
                                        } else {
                                                eval {
                                                        my $spec = VirtualMachineConfigSpec->new(changeTrackingEnabled => 'false');
                                                        print color("yellow") . "Disabling CBT on \"" . $vm->name . "\" ...\n" . color("reset");
                                                        my $task = $vm->ReconfigVM_Task(spec => $spec);
                                                        my $msg = color("green") . "\tSucessfully disabled CBT for \"" . $vm->name . "\"!\n" . color("reset");
                                                        &getStatus($task,$msg);
                                                };
                                        }
                                } else {
                                        print color("red") . "\"" . $vm->name . "\" is still powered on, VM needs to be powered off before CBT can be disabled!\n\n" . color("reset");
                                }
                       } else {
                                print color("red") . "\"" . $vm->name . "\" does not support CBT, feature only available on HW 7!\n\n" . color("reset");
                        }
                } else {
                        print color("red") . "Unable to find \"" . $vm->name . "\"!\n\n" . color("reset");
                }
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
		print color("red") . "This script requires your ESX(i) host to be greater than $host_version\n\n" . color("reset");
		exit 1;
	}

	########################
	# CHECK HOST LICENSE
	########################
	my $licenses = $licMgr->licenses;
	foreach(@$licenses) {
		if($_->editionKey eq 'esxBasic' && $host_license eq 'licensed') {
			Util::disconnect();
	                print color("red") . "This script requires your ESX(i) be licensed, the free version will not allow you to perform any write operations!\n\n" . color("reset");
			exit 1;
		}
	}

	########################
	# CHECK HOST TYPE
	########################
	if($service_content->about->apiType ne $host_type && $host_type ne 'both') {
		Util::disconnect();
                print color("red") . "This script needs to be executed against $host_type\n\n" . color("reset");
		exit 1
	}

	return $service_content->about->apiType;
}

sub getStatus {
        my ($taskRef,$message) = @_;

        my $task_view = Vim::get_view(mo_ref => $taskRef);
        my $taskinfo = $task_view->info->state->val;
        my $continue = 1;
        while ($continue) {
                my $info = $task_view->info;
                if ($info->state->val eq 'success') {
                        print $message,"\n";
                        return $info->result;
                        $continue = 0;
                } elsif ($info->state->val eq 'error') {
                        my $soap_fault = SoapFault->new;
                        $soap_fault->name($info->error->fault);
                        $soap_fault->detail($info->error->fault);
                        $soap_fault->fault_string($info->error->localizedMessage);
                        die "$soap_fault\n";
                }
                sleep 5;
                $task_view->ViewBase::update_view_data();
        }
}

# Subroutine to process the input file
sub processFile {
        my ($vmlist) =  @_;
        my $HANDLE;
        open (HANDLE, $vmlist) or die "ERROR: Unable to open \"$vmlist\" input file!\n";
        my @lines = <HANDLE>;
        my @errorArray;
        my $line_no = 0;

        close(HANDLE);
        foreach my $line (@lines) {
                $line_no++;
                &TrimSpaces($line);

                if($line) {
                        if($line =~ /^\s*:|:\s*$/){
                                &log("error", "Error in Parsing File at line: $line_no");
                                &log("info", "Continuing to the next line");
                                next;
                        }
			&TrimSpaces($line);
			push @vmlist, $line;
                }
        }
}

sub TrimSpaces {
        foreach (@_) {
        s/^\s+|\s*$//g
        }
}
