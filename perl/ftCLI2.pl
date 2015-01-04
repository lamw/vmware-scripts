#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://communities.vmware.com/docs/DOC-10279

# import runtime libraries 
use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;

# define custom options for vm and target host
my %opts = (
   'vmname' => {
      type => "=s",
      help => "The name of the virtual machine",
      required => 0,
   },
   'operation' => {
      type => "=s",
      help => "FT Operation to perform [create|enable|disable|stop|config_enable|config_disable]",
      required => 1,
   },
   'hostlist' => {
      type => "=s",
      help => "List of ESX(i) host to enable/disable configuration of FT",
      required => 0,
   },
   'portgroup_name' => {
      type => "=s",
      help => "Name of the portgroup to enable/disable FT",
      required => 0,
   },
);

# read and validate command-line parameters 
Opts::add_options(%opts);
Opts::parse();
Opts::validate();

# connect to the server and login
Util::connect();

my ($primaryVM,$task_ref,$hostlist,@hosts);

if( Opts::get_option('operation') eq 'config_enable') {
        if(Opts::get_option('hostlist') && Opts::get_option('portgroup_name')) {
		$hostlist = Opts::get_option('hostlist');
		&processConfigurationFile($hostlist);
		foreach(@hosts) {
			my $host_view = Vim::find_entity_view(view_type => 'HostSystem', filter => { name => $_ });
                	my $pg = Opts::get_option('portgroup_name');
                	my $ns = Vim::get_view (mo_ref => $host_view->configManager->networkSystem);
                	my $vs = Vim::get_view (mo_ref => $host_view->configManager->virtualNicManager);
			print "Enabling FT logging on \"$_\" for port group \"$pg\" ...\n";
                	&enable_or_disable(1,$ns, $pg, $vs);                               
                	print "\tSuccessfully enabled FT logging on \"$_\" for port group $pg.\n";
		}
        } else {
                die "Error: \"hostlist\"|\"portgroup_name\" variable needs to be defined when enabling/disabling configurations of FT!\n";
        }
} elsif( Opts::get_option('operation') eq 'config_disable') {
	if(Opts::get_option('hostlist') && Opts::get_option('portgroup_name')) {
		$hostlist = Opts::get_option('hostlist');
		&processConfigurationFile($hostlist);
		foreach(@hosts) {
        		my $host_view = Vim::find_entity_view(view_type => 'HostSystem', filter => { name => $_ });
			my $pg = Opts::get_option('portgroup_name');
			my $ns = Vim::get_view (mo_ref => $host_view->configManager->networkSystem);
			my $vs = Vim::get_view (mo_ref => $host_view->configManager->virtualNicManager);
			print "Disabling FT logging on \"$_\" for port group \"$pg\" ...\n";	
			&enable_or_disable(0,$ns, $pg, $vs);	
			print "\tSuccessfully disabled FT logging on \"$_\" for port group $pg.\n";
		}
	} else {
		die "Error: \"hostlist\"|\"portgroup_name\" variable needs to be defined when enabling/disabling configurations of FT!\n"; 
	}
} elsif( Opts::get_option('operation') eq 'create' ) {
	if( Opts::get_option('vmname') ) {
		$primaryVM = Vim::find_entity_view(view_type => 'VirtualMachine',
                                      filter => {"config.name" => Opts::get_option('vmname')});

		eval {
			$task_ref = $primaryVM->CreateSecondaryVM_Task();
			print "Creating FT secondary VM for \"" . $primaryVM->name . "\" ...\n";
			my $msg = "\tSuccessfully created FT protection for \"" . $primaryVM->name . "\"!";
			&getStatus($task_ref,$msg);
		};
		if ($@) {
        		# unexpected error
			print "Error: " . $@ . "\n\n";
		}
	} else {
                die "Error: \"vm\" variable needs to be defined when enabling/disabling configurations of FT!\n";
        }
} elsif( Opts::get_option('operation') eq 'enable' ) {
	if( Opts::get_option('vmname') ) {
        	$primaryVM = Vim::find_entity_view(view_type => 'VirtualMachine',
                                      filter => {"config.name" => Opts::get_option('vmname'), "config.ftInfo.role" => '1'});

	        my $uuids = $primaryVM->config->ftInfo->instanceUuids;
	        my $secondaryUuid = @$uuids[1];
	        my $secondaryVM = Vim::find_entity_view(view_type => 'VirtualMachine',
                                      filter => {"config.instanceUuid" => $secondaryUuid});
        	my $secondaryHost = Vim::get_view(mo_ref => $secondaryVM->runtime->host, properties => ['name']);

	        eval {
                	$task_ref = $primaryVM->EnableSecondaryVM_Task(vm => $secondaryVM);
        	        print "Enabling FT secondary VM for \"" . $primaryVM->name . "\" on host \"" . $secondaryHost->{'name'} . "\" ...\n";
	                my $msg = "\tSuccessfully enabled FT protection for \"" . $primaryVM->name . "\"!";
                	&getStatus($task_ref,$msg);
        	};
	        if ($@) {
	                # unexpected error
                	print "Error: " . $@ . "\n\n";
        	}
	} else {
                die "Error: \"vmname\" variable needs to be defined when enabling/disabling configurations of FT!\n";
        }
} elsif( Opts::get_option('operation') eq 'disable' ) {
	if( Opts::get_option('vmname') ) {
		$primaryVM = Vim::find_entity_view(view_type => 'VirtualMachine',
                                      filter => {"config.name" => Opts::get_option('vmname'), "config.ftInfo.role" => '1'});

		my $uuids = $primaryVM->config->ftInfo->instanceUuids;
		my $secondaryUuid = @$uuids[1];
		my $secondaryVM = Vim::find_entity_view(view_type => 'VirtualMachine',
                                      filter => {"config.instanceUuid" => $secondaryUuid});
		my $secondaryHost = Vim::get_view(mo_ref => $secondaryVM->runtime->host, properties => ['name']);

		eval {
			$task_ref = $primaryVM->DisableSecondaryVM_Task(vm => $secondaryVM);
			print "Disabling FT secondary VM for \"" . $primaryVM->name . "\" on host \"" . $secondaryHost->{'name'} . "\" ...\n";
	                my $msg = "\tSuccessfully disabled FT protection for \"" . $primaryVM->name . "\"!";
                	&getStatus($task_ref,$msg);
        	};
	        if ($@) {
	                # unexpected error
                	print "Error: " . $@ . "\n\n";
        	}
	} else {
                die "Error: \"vmname\" variable needs to be defined when enabling/disabling configurations of FT!\n";
        }
} elsif( Opts::get_option('operation') eq 'stop' ) {
	if( Opts::get_option('vmname') ) {
		$primaryVM = Vim::find_entity_view(view_type => 'VirtualMachine',
                                      filter => {"config.name" => Opts::get_option('vmname'), "config.ftInfo.role" => '1'});

		eval {
	                $task_ref = $primaryVM->TurnOffFaultToleranceForVM_Task();
	       	        print "Turning off FT for secondary VM for " . $primaryVM->name . " ...\n";
	                my $msg = "\tSuccessfully stopped FT protection for \"" . $primaryVM->name . "\"!";
                	&getStatus($task_ref,$msg);
        	};
        	if ($@) {
                	# unexpected error
        	        print "Error: " . $@ . "\n\n";
	        }
	} else {
                die "Error: \"vmname\" variable needs to be defined when enabling/disabling configurations of FT!\n";
        }
} else {
	print "Invalid operation!\n";
	print "Operations supported [create|enable|disable|stop]\n\n";
}

# close server connection
Util::disconnect();

sub getStatus {
	my ($taskRef,$message) = @_;
	
	my $task_view = Vim::get_view(mo_ref => $taskRef);
	my $taskinfo = $task_view->info->state->val;
	my $continue = 1;
	while ($continue) {
        	my $info = $task_view->info;
        	if ($info->state->val eq 'success') {
			print $message,"\n";
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

sub enable_or_disable {
   my ($enable, $ns, $pg, $vs) = @_;
   my $vnic = find_vnic($ns, $pg);
   eval {
      if ($vnic) {
         if ($vs->isa('HostVirtualNicManager')) {
            if ($enable) {
               $vs->SelectVnicForNicType(nicType => "faultToleranceLogging",
                                          device => $vnic->device);
            } else {
               $vs->DeselectVnicForNicType(nicType => "faultToleranceLogging",
                                            device => $vnic->device);
            }
         } else {
            if ($enable) {
               $vs->SelectVnic(device => $vnic->device);
            } else {
               $vs->DeselectVnic();
            }
         }
      } else {
         VIExt::fail("Failed to " . ($enable ? "enable" : "disable") .
                  " VMkernel NIC for FT: " . "device not found");
      }
   };
   if ($@) {
      VIExt::fail("Failed to " . ($enable ? "enable" : "disable") .
                  " VMkernel NIC for FT: " . ($@->fault_string));
   }
}

sub find_vnic {
   my ($ns, $pg, $dvsName, $dvportId) = @_;
   if (defined($ns->networkInfo)) {
      my $vnics = $ns->networkInfo->vnic;
      my $vnic;
      
      if (defined($pg)) {
         foreach $vnic (@$vnics) {
            if ($vnic->portgroup && $pg eq $vnic->portgroup) {
               return $vnic;
            }
         }
      } elsif (defined($dvsName)) {
         my $sUuid = getSwitchUuid($ns, $dvsName);
         foreach $vnic (@$vnics) {
            if ($vnic->spec->distributedVirtualPort && ($dvportId eq $vnic->spec->distributedVirtualPort->portKey) && ($sUuid eq $vnic->spec->distributedVirtualPort->switchUuid)) {
               return $vnic;
            }         
         }
      }
   }
   return undef;
}

# Subroutine to process the input file
sub processConfigurationFile {
        my ($local_conf) = @_;
        my $CONF_HANDLE;

        open(CONF_HANDLE, "$local_conf") || die "Couldn't open file \"$local_conf\"!\n";
        while (<CONF_HANDLE>) {
                chomp;
                s/#.*//; # Remove comments
                s/^\s+//; # Remove opening whitespace
                s/\s+$//;  # Remove closing whitespace
                next unless length;

                push @hosts,$_;
        }
        close(CONF_HANDLE);
}
