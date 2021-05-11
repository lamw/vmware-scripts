#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://www.williamlam.com/2010/06/script-hostops-lamwpl.html

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../";

use VMware::VIRuntime;
use AppUtil::HostUtil;

$Util::script_version = "1.0";

my %operations = (
   "add_standalone", "",
   "disconnect", "" ,
   "reconnect", "" ,
   "enter_maintenance", "",
   "exit_maintenance", "",
   "reboot", "",
   "shutdown", "",
   "addhost", "",
   "removehost", "",
   "moveintofolder", "",
   "moveintocluster", "",
);

my %opts = (
   target_host => {
      type => "=s",
      help => "Target host",
      required => 1,
   },
   target_username => {
      type => "=s",
      help => "Target host username ",
      required => 0,
   },
   target_password => {
      type => "=s",
      help => "Target host password ",
      required => 0,
   },
   # bug 300034
   operation => {
      type => "=s",
      help => "Operation to perform on target host:"
               ."add_standalone, disconnect, enter_maintenance,"
               ."exit_maintenance, reboot, shutdown, addhost, reconnect,"
               ."removehost, moveintofolder, moveintocluster",
      required => 1,
   },
   suspend => {
      type => "=i",
      help => " Flag to specify whether or not to suspend the virtual machines",
      required => 0,
      default => 0,
   },
   quiet => {
      type => "=i",
      help => " Flag to specify whether or not to provide progress messages"
            . " as the virtual machines are suspended for some operations.",
      required => 0,
      default => 1,
   },
   port => {
      type => "=s",
      help => " The port number for the connection",
      required => 0,
   },
   cluster => {
      type => "=s",
      help => " The cluster in which to add the host",
      required => 0,
   },
   folder => {
      type => "=s",
      help => " The folder in which to add the host",
      required => 0,
   },
   force => {
      type => "=i",
      help => " Flag to specify whether or not to force the addition of host"
            . " even if this is being managed by other virtual center.",
      required => 0,
      default => 0,
   },
   sslthumbprint => {
     type => "=s",
     help => "SSL Thumbprint for ESX or ESXi host to be added to vCenter",
     required => 0,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate(\&validate);

Util::connect();

my $sslthumbprint = Opts::get_option('sslthumbprint');
my $operation = Opts::get_option('operation');
my $target_host = Opts::get_option('target_host');
my $entity_view;
my $folder_views;
my $folder;
my $cluster;
my $cluster_views;
my %filterHash = create_hash($target_host );
my $suspendFlag = Opts::get_option('suspend');
my $quietflag = Opts::get_option('quiet');

if (Opts::get_option('operation') eq 'add_standalone') {
   $folder_views = get_folder_views();
   add_standalone_host($folder_views);
}
elsif (Opts::get_option('operation') eq 'addhost') {
    add_host();
}
else {
   my $host_views = HostUtils::get_hosts ('HostSystem',undef,undef, %filterHash);
   if ($host_views) {
      $entity_view = shift @$host_views;
      if( $operation eq "disconnect" ) {
         disconnect_host($entity_view);
      }
      elsif( $operation eq "reconnect" ) {
         reconnect_host($entity_view);
      }
      elsif( $operation eq "enter_maintenance" ) {
         enter_maintenance_mode($entity_view);
      }
      elsif( $operation eq "exit_maintenance" ) {
         exit_maintenance_mode($entity_view);
      }
      elsif( $operation eq "reboot" ) {
         reboot_host($entity_view);
      }
      elsif( $operation eq "shutdown" ) {
         shutdown_host($entity_view);
      }
      elsif( $operation eq "removehost" ) {
        remove_host($entity_view);
      }
      elsif( $operation eq "moveintofolder" ) {
         move_into_folder($entity_view);
      }
      elsif( $operation eq "moveintocluster" ) {
         move_into_cluster($entity_view);
      }
   }
}

Util::disconnect();

sub create_hash {
   my ($target_host) = @_;
   my %filterHash;
   if ($target_host) {
      $filterHash{'name'} = $target_host;
   }
   return %filterHash;
}

sub get_folder_views {
my $folder_name = Opts::get_option('folder');

   if (defined Opts::get_option('folder')) {
      $folder_views =
         Vim::find_entity_views(view_type => 'Folder',
                                   filter => {name => $folder_name});
      if (@$folder_views) {
         $folder = shift @$folder_views;
         return $folder;
      }
      else {
         Util::trace(0,"No folder found\n ");
         return $folder;
      }
   }
   else {
     $folder_views =
         Vim::find_entity_views(view_type => 'Folder');
      foreach(@$folder_views) {
         my $folder = $_;
         my $childType = $folder->childType;
         foreach(@$childType){
            if($_ eq "ComputeResource") {
               return $folder;
            }
         }
      }
      Util::trace(0,"No folder found\n");
      return;
   }
}


sub get_cluster_views {
my $cluster_name = Opts::get_option('cluster');

   if (defined Opts::get_option('cluster')) {
      $cluster_views =
         Vim::find_entity_views(view_type => 'ClusterComputeResource',
                                   filter => {name => $cluster_name});
      if (@$cluster_views) {
         $cluster = shift @$cluster_views;
         return $cluster;
      }
      else {
         Util::trace(0,"No cluster found\n ");
         return $cluster;
      }
   }
}


#Add host to a cluster
#
sub add_host {
   my $target_host = Opts::get_option('target_host');
   my $target_username = Opts::get_option('target_username');
   my $target_password = Opts::get_option('target_password');
   my $port = Opts::get_option('port');
   my $force = Opts::get_option('force');
   my $clusterfound = get_cluster_views();
   if(defined $clusterfound) {
	my $host_connect_spec = "";
      eval {
	 if(!defined($sslthumbprint)) {
         	$host_connect_spec = (HostConnectSpec->new(force => ($force || 0),
                                                       hostName => $target_host,
                                                       userName => $target_username,
                                                       password => $target_password,
                                                       port => $port,
                                                      ));
	 } else {
		$host_connect_spec = (HostConnectSpec->new(force => ($force || 0),
                                                       hostName => $target_host,
                                                       userName => $target_username,
                                                       password => $target_password,
                                                       port => $port,
						       sslThumbprint => $sslthumbprint,
                                                      ));
         }
       $cluster->AddHost(spec => $host_connect_spec, asConnected => 1);
       my $host_views = HostUtils::get_hosts ('HostSystem',undef,undef, %filterHash);
       if ($host_views) {
          $entity_view = shift @$host_views;
       }
       # defect 224265
       my $check_mode = $entity_view->runtime->inMaintenanceMode;
       if($check_mode == 1) {
          exit_maintenance_mode($entity_view);
       }
       Util::trace(0, "\nHost '$target_host' added successfully\n");
     };
     if ($@) {
        if (ref($@) eq 'SoapFault') {
           if (ref($@->detail) eq 'DuplicateName') {
              Util::trace(0,"\nHost $target_host already exist\n");
           }
           elsif (ref($@->detail) eq 'AlreadyConnected') {
              Util::trace(0, "\nSpecified host is already ".
                             "connected to the Virtual Center\n");
           }
           elsif (ref($@->detail) eq 'NoHost') {
              Util::trace(0, " \nSpecified host does not exist\n");
           }
           elsif (ref($@->detail) eq 'AlreadyBeingManaged') {
              Util::trace(0, " \nHost is already being managed by other host\n");
           }
           elsif (ref($@->detail) eq 'InvalidLogin') {
              Util::trace(0, "\nHost authentication failed."
                           ." Invalid Username and\/or Password\n ");
           }
           else {
              Util::trace(0, "Error: "  . $@ . " ");
           }
        }
        else {
           Util::trace(0, "Error: "  . $@ . " ");
        }
     }
   }
   else {
       Util::trace(0," ");
   }
}


#Remove host
#
sub remove_host {
   my $target_host = shift;
   my $host_name = Opts::get_option('target_host');
# Bug 289362  fix start 
   if ($entity_view->parent->type eq 'ComputeResource') {
      $target_host = ($entity_view->parent);
      my $target_host_view = Vim::get_view(mo_ref => $target_host);
      $target_host =  $target_host_view;
   }
   elsif ($entity_view->parent->type eq 'ClusterComputeResource') {
      $target_host = ($entity_view);
      if (!$entity_view->runtime->inMaintenanceMode) {
           enter_maintenance_mode($entity_view);
      }
   }
# Bug 289362  fix end
   eval {
     $target_host->Destroy();
     Util::trace(0, "\nHost '$host_name' removed successfully\n");
   };
   if ($@) {
      if (ref($@) eq 'SoapFault') {
         if (ref($@->detail) eq 'InvalidState') {
            Util::trace(0,"\n The operation is not allowed in the current state\n");
         }
         elsif (ref($@->detail) eq 'RuntimeFault') {
            Util::trace(0,"\nRuntime Fault\n");
         }
         else {
            Util::trace(0, "Error: "  . $@ . " ");
         }
      }
      else {
         Util::trace(0, "Error: "  . $@ . " ");
      }
   }
}

#Move the existing host into cluster
sub move_into_cluster {
my $clusterfound = get_cluster_views();
my $flag = 0;
   # Bug 289362  / 223627 fix start 
   if(defined $clusterfound) {
      my $cluster_name = Opts::get_option('cluster');
      my  @listArray = ($entity_view);
      eval {
         if ($entity_view->parent->type eq 'ClusterComputeResource') {
            if (!$entity_view->runtime->inMaintenanceMode) {
                enter_maintenance_mode($entity_view);
                $flag = 1;
             }
         }
         $cluster->MoveInto(host=>@listArray);
          Util::trace(0,"\nHost $target_host moved into cluster $cluster_name \n");
            if($flag == 1){
                  exit_maintenance_mode($entity_view);
            }
   # Bug 289362  223627 fix end 
        
      };
      if ($@) {
         if (ref($@) eq 'SoapFault') {
            if (ref($@->detail) eq 'DuplicateName') {
               Util::trace(0,"\nHost $target_host already exist\n");
            }
            elsif (ref($@->detail) eq 'InvalidFolder') {
               Util::trace(0, "\nInvalid folder");
            }
            elsif (ref($@->detail) eq 'InvalidState') {
               Util::trace(0, " \nmoveintocluster operation is not allowed in "
                              ."the current state\n");
            }
            elsif (ref($@->detail) eq 'InvalidArgument') {
               Util::trace(0, " \nA specified parameter was not correct\n");
            }
            elsif (ref($@->detail) eq 'NotSupported') {
               Util::trace(0, "\nmovehost operation is not supported on the object\n");
            }
            else {
               Util::trace(0, "Error: "  . $@ . " ");
            }
        }
        else {
           Util::trace(0, "Error: "  . $@ . " ");
        }
      }
   }
   else {
       Util::trace(0," ");
   }
}


sub move_into_folder {
my $folderfound = get_folder_views();
# bug 223627 fix start
my $flag = 0;
   if(defined $folderfound) {
      my $folder_name = Opts::get_option('folder');

      # defect 270711
      my  @listArray = undef;
      if ($entity_view->parent->type eq 'ComputeResource') {
         @listArray = ($entity_view->parent);
      }
      elsif ($entity_view->parent->type eq 'ClusterComputeResource') {
         @listArray = ($entity_view);
         if (!$entity_view->runtime->inMaintenanceMode) {
             enter_maintenance_mode($entity_view);
         $flag = 1;
         }
      } else {
         @listArray = ($entity_view);
      }
      eval {
         $folder->MoveIntoFolder(list=>@listArray);
         Util::trace(0,"\nHost $target_host moved into folder $folder_name \n");
       if($flag == 1){
                  exit_maintenance_mode($entity_view);
            }
# bug 223627 fix end
        
      };
      if ($@) {
         if (ref($@) eq 'SoapFault') {
            if (ref($@->detail) eq 'DuplicateName') {
               Util::trace(0,"\nHost $target_host already exist\n");
            }
            elsif (ref($@->detail) eq 'InvalidFolder') {
               Util::trace(0, "\nInvalid folder");
            }
            elsif (ref($@->detail) eq 'InvalidState') {
               Util::trace(0, " \nmoveinto folder operation is not allowed in the "
                              ."current state\n");
            }
            elsif (ref($@->detail) eq 'InvalidArgument') {
               Util::trace(0, " \nA specified parameter was not correct\n");
            }
            elsif (ref($@->detail) eq 'NotSupported') {
               Util::trace(0, "\nmoveinto folder operation is not supported on the object\n");
            }
            else {
               Util::trace(0, "Error: "  . $@ . " ");
            }
         }
         else {
            Util::trace(0, "Error: "  . $@ . " ");
         }
     }
  }
  else {
     Util::trace(0, " ");
   }
}

# Add standalone server host
sub add_standalone_host {
   my $folder = shift;
   my $target_host = Opts::get_option('target_host');
   my $target_username = Opts::get_option('target_username');
   my $target_password = Opts::get_option('target_password');
   my $port = Opts::get_option('port');
   my $force = Opts::get_option('force');
   eval {
      my $host_connect_spec = (HostConnectSpec->new(force => ($force || 0),
                                                    hostName => $target_host,
                                                    userName => $target_username,
                                                    password => $target_password,
                                                    port => $port,
                                                   ));
     $folder->AddStandaloneHost(spec => $host_connect_spec, addConnected => 1);
     my $host_views = HostUtils::get_hosts ('HostSystem',undef,undef, %filterHash);
     if ($host_views) {
        $entity_view = shift @$host_views;
     }
      Util::trace(0, "\nHost '$target_host' added successfully\n");
   };
   if ($@) {
      if (ref($@) eq 'SoapFault') {
         if (ref($@->detail) eq 'DuplicateName') {
            Util::trace(0,"\nHost $target_host already exist\n");
         }
         elsif (ref($@->detail) eq 'AlreadyConnected') {
            Util::trace(0, "\nSpecified host is already ".
                             "connected to the Virtual Center\n");
         }
         elsif (ref($@->detail) eq 'NoHost') {
            Util::trace(0, " \nSpecified host does not exist\n");
         }
         elsif (ref($@->detail) eq 'InvalidLogin') {
            Util::trace(0, "\nHost authentication failed."
                           ." Invalid Username and\/or Password\n ");
         }
         else {
            Util::trace(0, "Error: "  . $@ . " ");
         }
      }
      else {
         Util::trace(0, "Error: "  . $@ . " ");
      }
   }
}

# Disconnect a host
# -----------------
sub disconnect_host {
   my $target_host = shift;
   eval {
      $target_host->DisconnectHost();
      Util::trace(0, "\nHost '" . $target_host->name . "' disconnected successfully\n");
   };
   if ($@) {
      if (ref($@) eq 'SoapFault') {
         if (ref($@->detail) eq 'NotSupported') {
            Util::trace(0,"\nRunning directly on an ESX Server host.");
         }
         elsif (ref($@->detail) eq 'InvalidState') {
            Util::trace(0,"\nThe operation is not allowed in the current state.\n");
         }
         else {
            Util::trace (0, "\nHost  can't be disconnected \n" . $@. "" );
         }
      }
      else {
         Util::trace (0, "\nHost  can't be disconnected \n" . $@. "" );
      }
   }
}

# Reconnect a host
# ----------------
sub reconnect_host {
   my $target_host = shift;
   eval {
      $target_host->ReconnectHost();
      Util::trace(0, "\nHost '" . $target_host->name . "' reconnected successfully\n");
   };
   if ($@) {
      if (ref($@) eq 'SoapFault') {
         if (ref($@->detail) eq 'InvalidState') {
            Util::trace(0,"\nThe operation is not allowed in the current state\n");
         }
         elsif (ref($@->detail) eq 'AlreadyBeingManaged') {
            Util::trace(0,"\nHost is already being managed by"
                         . " another VirtualCenter server\n");
         }
         else {
            Util::trace(0,"\nHost  can't be reconnected \n" . $@. "");
         }
      }
      else {
         Util::trace(0,"\nHost  can't be reconnected \n" . $@. "");
      }
   }
}

# This subroutine is used to suspend the virtual machines, it is called from
# enter_maintenance, reboot, shutdown_host subroutines
sub suspend_vm {
   my $target_host = shift;
   my $vm_views = Vim::get_views(mo_ref_array => $target_host->vm);
   foreach (@$vm_views) {
      if ($_->runtime->powerState->val eq 'poweredOn') {
## bug 299737  fix start
         if ($suspendFlag != 1) {
            Util::trace(0, "\nThis operation is not allowed as one or".
                           " more Virtual machines is currently powered On \n");
            return 1;
         }
## bug 299737  fix end
         elsif ($suspendFlag ==1) {
            if($quietflag==0) {
               Util::trace(0, "\nSuspending virtual machine: '" . $_->name . "'...");
            }
            eval {
               $_->SuspendVM();
               if($quietflag==0) {
                  Util::trace($quietflag, "\n\nVirtual machine '" . $_->name
                                  . "' Suspended successfully\n");
               }
            };
            if ($@) {
               if (ref($@) eq 'SoapFault') {
                  if (ref($@->detail) eq 'InvalidPowerState') {
                     Util::trace(0,"\nVM should be powered on");
                  }
                  elsif (ref($@->detail) eq 'NotSupported') {
                     Util::trace(0,"\nVirtual machine is marked as a template.");
                  }
                  else {
                     Util::trace(0,"\nVM cannot be suspended \n" . $@. "");
                  }
               }
               else {
                  Util::trace(0,"\nVM cannot be suspended \n" . $@. "");
               }
            }
         }
      }
   }
}



# This is used to enter the host in maintenance mode. All the powered On VM's
# are first suspended if the suspend flag is set to '1' else if suspend flag
# is set to '0' then the operation will not be performed if any of the virtual
# machine is powered On.
sub enter_maintenance_mode {
   my $target_host = shift;
   my $suspend_call = 0 ;
   $suspend_call = suspend_vm($entity_view);
   if((defined $suspend_call)&&($suspend_call ==1)) {
      return;
   }
   eval {
      $target_host->EnterMaintenanceMode(timeout => 0);
      Util::trace(0, "\nHost '" . $target_host->name
                   . "' entered maintenance mode successfully\n");
   };
   if ($@) {

      if (ref($@) eq 'SoapFault') {
         if (ref($@->detail) eq 'InvalidState') {
            Util::trace(0,"\nThe enter_maintenancemode operation".
            " is not allowed in the current state");
         }
         elsif (ref($@->detail) eq 'Timedout') {
            Util::trace(0,"\nOperation is timed out\n");
         }
         elsif (ref($@->detail) eq 'HostNotConnected') {
            Util::trace(0,"\nUnable to communicate with the"
                         . " remote host, since it is disconnected.\n");
         }
         else {
            Util::trace(0,"\nHost cannot be entered into maintenance mode \n" . $@. "");
         }
      }
      else {
         Util::trace(0,"\nvvgmvnvnost cannot be entered into maintenance mode \n" . $@. "");
      }
   }
}


# This subroutine is used to exit the host from maintenance mode
# --------------------------------------------------------------
sub exit_maintenance_mode {
   my $target_host = shift;
   eval {
      $target_host->ExitMaintenanceMode(timeout => 0);
      Util::trace(0, "\nHost '" . $target_host->name
                   . "' exited maintenance mode successfully\n ");
   };
   if ($@) {
      if (ref($@) eq 'SoapFault') {
         if (ref($@->detail) eq 'InvalidState') {
            Util::trace(0,"\nThe operation is not allowed in the current state");
         }
         else {
            Util::trace(0,"\nHost cannot exit maintenance mode \n" . $@. "");
         }
      }
      else {
         Util::trace(0,"\nHost cannot exit maintenance mode \n" . $@. "");
      }
   }
}

# This subroutine is required for rebooting the host. All the powered On VM's
# are first suspended if the suspend flag is set to '1' else if suspend flag
# is set to '0' then the operation will not be performed if any of the virtual
# machine is powered On.
sub reboot_host {
   my $target_host = shift;
   if(suspend_vm($entity_view)==1) {
      return;
   }
   eval {
      $target_host->RebootHost(force => 0);
      Util::trace(0, "\nHost '" . $target_host->name . "' rebooted successfully\n");
   };
   if ($@) {
      if (ref($@) eq 'SoapFault') {
         if (ref($@->detail) eq 'InvalidState') {
            Util::trace(0,"\nThe operation is not allowed in the current state");
         }
         elsif (ref($@->detail) eq 'HostNotConnected') {
            Util::trace(0,"\nUnable to communicate"
                         . " with the remote host, since it is disconnected");
         }
         else {
            Util::trace (0,"\nHost  can't reboot \n"  . $@ ."" );
         }
      }
      else {
         Util::trace (0,"\nHost  can't reboot \n"  . $@. "" );
      }
   }
   if ($target_host->runtime->inMaintenanceMode) {
      exit_maintenance_mode($entity_view);
   }
}

# This is used for shutting down the host. All the powered On VM's
# are first suspended if the suspend flag is set to '1' else if suspend flag
# is set to '0' then the operation will not be performed if any of the virtual
# machine is powered On.

sub shutdown_host {
   my $target_host = shift;
   if(suspend_vm($entity_view)==1) {
      return;
   }
   eval {
      $target_host->ShutdownHost(force => 0);
      Util::trace(0, "\nShutdown of host '" . $target_host->name
                   . "' done successfully\n");
   };
   if ($@) {
      if (ref($@) eq 'SoapFault') {
         if (ref($@->detail) eq 'InvalidState') {
            Util::trace(0,"\nThe operation is not allowed in the current state");
         }
         else {
            Util::trace(0,"\nCan't shutdown host\n" . $@ ."" );
         }
      }
   }
}

sub validate {
   my $operation = Opts::get_option('operation');
  my $valid = 1;
   if (($operation eq 'add_standalone') &&
         ((!Opts::option_is_set('target_username'))||
         !Opts::option_is_set('target_password'))) {
       Util::trace(0, "Must specify target_username and target_password "
                    . "options for add_standalone operation \n");
       $valid = 0;
   }
   if (($operation eq 'addhost') &&
         ((!Opts::option_is_set('target_username'))||
         (!Opts::option_is_set('target_password'))||(!Opts::option_is_set('cluster')))) {
       Util::trace(0, "Must specify target_username and target_password and cluster "
                    . "options for addhost operation \n");
       $valid = 0;
   }
 # Bug 289362/300062/300066  fix start 
   if (($operation eq 'moveintofolder') &&
        (!Opts::option_is_set('folder'))) {
       Util::trace(0, "Must specify folder name "
                    . "options for moveinto folder operation \n");
       $valid = 0;
   }
   if (($operation eq 'moveintocluster') &&
        (!Opts::option_is_set('cluster'))){
      Util::trace(0, "Must specify cluster "
                    . "name options for moveinto cluster operation \n");
      $valid = 0;
   }
 # Bug 289362/300062/300066  fix end
   if (!exists($operations{$operation})) {
      Util::trace(0,"\nInvalid operation: $operation\n");
      Util::trace(0,"List of valid operations \n");
      map { print "  $_\n"; } sort keys %operations;
      $valid = 0;
   }
   return $valid;
}

__END__

## bug 217605

=head1 NAME

hostops.pl - Performs these operations: add standalone, disconnect, reconnect,
enter maintenance mode, exit from maintenance mode, reboot, shutdown host, add host, remove host,
and move host into folder/cluster.

=head1 SYNOPSIS

 hostops.pl --operation <disconnect|reconnect|enter_maintenance|
              exit_maintenance|reboot|shutdown|add_standalone|
              addhost|moveintofolder|moveintocluster|removehost> [options]

=head1 DESCRIPTION

This script allows users to perform basic operations on the host server.
The supported operations are: add_standalone, disconnect,
reconnect, enter_maintenance, exit_maintenance, reboot, shutdown, addhost
moveintofolder, moveintocluster, removehost.

=head1 OPTIONS

=over

=item B<operation>

Required. Operation to be performed must be one of the following:

I<shutdown> E<ndash> shutdown the host

I<reboot> E<ndash> reboot the host

I<enter_maintenance> E<ndash> set host into maintenance mode

I<exit_maintenance> E<ndash> exit the maintenance mode

I<disconnect> E<ndash> disconnect the host

I<reconnect> E<ndash> reconnect the host

I<add_standalone> E<ndash> add new host

I<addhost> E<ndash> add host to a cluster

I<moveintofolder> E<ndash> move host out of a cluster to a folder

I<moveintocluster> E<ndash> move host out of a folder to a cluster

I<removehost> E<ndash> remove move host

=back

=head2 ADD STANDALONE OPTIONS

=over

=item B<target_host>

Required. Domain name or IP address of the target host.

=item B<target_username>

Required. Username for logging into the VirtualCenter server to be added.

=item B<target_password>

Required. Password for logging into the VirtualCenter server to be added.

=back

=head2 ADD HOST OPTIONS

=over

=item B<target_host>

Required. Domain name or IP address of the target host.

=item B<target_username>

Required. Username for logging into the VirtualCenter server to be added.

=item B<target_password>

Required. Password for logging into the VirtualCenter server to be added.

=item B<cluster>

Required. Name of the cluster into which host is to be added.

=item B<force>

Optional. Flag to specify whether or not to force the addition of host
even if this is being managed by other virtual center.

=item B<port>

Optional. Port number for the connection.

=back

=head2 MOVE HOST INTO FOLDER OPTIONS

=over

=item B<target_host>

Required. Domain name or IP address of the target host.

=item B<folder>

Required. Folder name into which host is to be moved in from the cluster in the
current datacenter.

=back

=head2 MOVE HOST INTO CLUSTER OPTIONS

=over

=item B<target_host>

Required. Domain name or iIP address of the target host.

=item B<cluster>

Required. Cluster name into which host is to be moved in from the folder in the
current datacenter.

=back

=head2 REMOVE HOST OPTIONS

=over

=item B<target_host>

Required. Domain name or IP address of the target host.

=back

=head2 DISCONNECT HOST OPTIONS

=over

=item B<target_host>

Required. Domain name or IP address of the target host.

=back

=head2 RECONNECT HOST OPTIONS

=over

=item B<target_host>

Required. Domain name or IP address of the target host.

=back

=head2 ENTER MAINTENANCE MODE OPTIONS

=over

=item B<target_host>

Required. Domain name or IP address of the target host.

=item B<suspend>

Optional. Flag to specify whether or not to suspend to virtual machine.

=item B<quiet>

Optional. Flag to specify whether or not to provide progress messages
as the virtual machines are suspended for some operations.

=back

=head2 EXIT MAINTENANCE MODE OPTIONS

=over

=item B<target_host>

Required. Domain name or IP address of the target host.

=back

=head2 SHUTDOWN OPTIONS

=over

=item B<target_host>

Required. Domain name or IP address of the target host.

=item B<suspend>

Optional. Flag to specify whether or not to suspend to virtual machine.

=item B<quiet>

Optional. Flag to specify whether or not to provide progress messages
as the virtual machines are suspended for some operations.

=back

=head2 REBOOT OPTIONS

=over

=item B<target_host>

Required. Domain name or IP address of the target host.

=item B<suspend>

Optional. Flag to specify whether or not to suspend to virtual machine.
Default: 0

=item B<quiet>

Optional. Flag to specify whether or not to provide progress messages
as the virtual machines are suspended for some operations.
Default: 1

=back

=head1 EXAMPLES

Shut down a host with progress messages. i.e "quiet = 0":

 hostops.pl --username root --password esxadmin --operation shutdown
           --url https://<ipaddress>:<port>/sdk/webService
           --target_host targetABC --suspend 1 --quiet 0

Reboot a host with progress messages. i.e "quiet = 0":

 hostops.pl --username root --password esxadmin --operation reboot
           --url https://<ipaddress>:<port>/sdk/webService
            --target_host targetABC --suspend 1 --quiet 0

Enter maintenance mode with no progress messages. i.e "quiet = 1":

 hostops.pl --username root --password esxadmin --operation enter_maintenance
           --url https://<ipaddress>:<port>/sdk/webService
           --target_host targetABC --suspend 1 --quiet 1

Exit maintenance mode:

 hostops.pl --username root --password esxadmin --operation exit_maintenance
           --url https://<ipaddress>:<port>/sdk/webService
           --target_host targetABC

Reconnect a host:

 hostops.pl --url https://<ipaddress>:<port>/sdk/webService --username user
           --password mypassword --target_host targetABC
           --operation reconnect

Disconnect a host:

 hostops.pl --url https://<ipaddress>:<port>/sdk/webService --username user
           --password mypassword --target_host targetABC
           --operation disconnect

Add standalone host, this host is already being managed by other virtual center
use force option to add it to the given virtual center:

 hostops.pl --url https://<ipaddress>:<port>/sdk/webService --username user
           --password mypassword --target_host targetABC
           --target_username root --target_password esxadmin
           --operation add_standalone --force 1

Remove host:

 hostops.pl --url https://<ipaddress>:<port>/sdk/webService --username user
           --password mypassword --target_host targetABC
            --operation removehost

Add host to a cluster:

 hostops.pl --url https://<ipaddress>:<port>/sdk/webService --username user
           --password mypassword --target_host targetABC
           --operation addhost --cluster myCluster

Move host from cluster to a folder:

 hostops.pl --url https://<ipaddress>:<port>/sdk/webService --username user
           --password mypassword --target_host targetABC
           --operation moveintofolder --folder myFolder

Move host from folder to a cluster:

 hostops.pl --url https://<ipaddress>:<port>/sdk/webService --username user
           --password mypassword --target_host targetABC
           --operation moveintocluster --cluster mycluster

=head1 SUPPORTED PLATFORMS

Only enter_maintenance, exit_maintenance, shutdown, and reboot work with ESX Sever 3.0.1.
