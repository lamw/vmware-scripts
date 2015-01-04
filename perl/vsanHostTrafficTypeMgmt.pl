#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://www.virtuallyghetto.com/2014/03/exploring-vsan-apis-part-3-enable-vsan-traffic-type.html

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;

# define custom options for vm and target host
my %opts = (
   'cluster' => {
      type => "=s",
      help => "Name of vSphere VSAN Cluster",
      required => 1,
   },
   'vihost' => {
      type => "=s",
      help => "Name of an ESXi host within VSAN Cluster",
      required => 0,
   },
   'vmk' => {
      type => "=s",
      help => "Name of the VMkernel interface to enable or disable",
      required => 0,
   },
   'operation' => {
      type => "=s",
      help => "Operation to perform [query|enable|disable]",
      required => 1,
   },
);

$SIG{__DIE__} = sub{Util::disconnect()};

# read and validate command-line parameters 
Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $vihost = Opts::get_option("vihost");
my $cluster = Opts::get_option("cluster");
my $vmk = Opts::get_option("vmk");
my $operation = Opts::get_option("operation");

my $cluster_view = Vim::find_entity_view(view_type => 'ComputeResource', filter => { 'name' => $cluster});
unless($cluster_view) {
       	Util::disconnect();
       	print "Error: Unable to find vSphere Cluster " . $cluster . "\n";
       	exit 1;
}

if($operation eq 'enable' || $operation eq 'disable') {
	unless($vmk && $vihost) {
		Util::disconnect();
		print "Error: For enable/disable operation please specify the --vmk & --vihost option\n";
		exit 1;
	}
	my $host_view = Vim::find_entity_view(view_type => 'HostSystem', filter => { 'name' => $vihost});
	unless($cluster_view) {
		Util::disconnect();
		print "Error: Unable to find ESXi host " . $vihost . "\n";
		exit 1;
	}

	# Array of VMkernel objects to modify
	my @vmkernelList = &getEnabledVMkernelInt($cluster_view,$host_view,$vmk);

	# Reconfigure vSphere Cluster with list of VMkernel interface + ESXi host
	my $networkInfo = VsanHostConfigInfoNetworkInfo->new(port => \@vmkernelList);
	my $hostSpec = VsanHostConfigInfo->new(hostSystem => $host_view, networkInfo => $networkInfo);
	my $spec = ClusterConfigSpecEx->new(vsanHostConfigSpec => [$hostSpec]);

	print "Reconfiguring " . $vihost . " in Cluster " . $cluster . "...\n";
	my $task = $cluster_view->ReconfigureComputeResource_Task(modify => 'true', spec => $spec);

	my $msg = "\tSuccessfully reconfigured ESXi host";
	&getStatus($task,$msg);
}elsif($operation eq 'query') {
	my $hosts = $cluster_view->configurationEx->vsanHostConfig;
	foreach my $host(@$hosts) {
		my $host_view = Vim::get_view(mo_ref => $host->hostSystem, properties => ['name']);
		print "Host: " . $host_view->{'name'} . "\n";
		my $vsanHostPorts = $host->networkInfo->port;
		my @interfaces = ();
		foreach my $vsanHostPort(@$vsanHostPorts) {
			push @interfaces,$vsanHostPort->device;
		}
		print "VSAN Enabled VMkernel interfaces: " . join(',',@interfaces) . "\n\n";
	}
} else {
	print "Invalid selection!\n";
	exit 1;
}

Util::disconnect();

sub getEnabledVMkernelInt {
	my ($cluster_view,$host_view,$vmk) = @_;

	# Get list of VMkernel interfaces that were enabled
  my @originalEnabledVmk = ();
  my $hosts = $cluster_view->configurationEx->vsanHostConfig;
  foreach my $host(@$hosts) {
  	my $seen_host_view = Vim::get_view(mo_ref => $host->hostSystem, properties => ['name']);
    if($seen_host_view->{'name'} eq $host_view->name) {
    	my $vsanHostPorts = $host->networkInfo->port;
      foreach my $vsanHostPort(@$vsanHostPorts) {
      	push @originalEnabledVmk,$vsanHostPort->device;
      }
    }
  }

	my @result = ();
	# Append the new VMkernel interface to the existing list
  if($operation eq 'enable') {
		if(exists {map { $_ => 1 } @originalEnabledVmk}->{$vmk}) {
			Util::disconnect();
			print "Error: " . $vmk . " has already been enabled\n";
			exit 1;
		} else {
	  	push @originalEnabledVmk,$vmk;
			foreach (@originalEnabledVmk) {
				my $tmp = VsanHostConfigInfoNetworkInfoPortConfig->new(device => $_);
				push @result,$tmp;
			}
		}
	} else {
		# Remove the specified VMkernel from the existing list
  	my @originalEnabledVmk = grep(!/$vmk/,@originalEnabledVmk);
		foreach (@originalEnabledVmk) {
			my $tmp = VsanHostConfigInfoNetworkInfoPortConfig->new(device => $_);
			push @result,$tmp;
		}
  }
	return @result;
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
