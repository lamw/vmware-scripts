#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://www.williamlam.com/2014/03/exploring-vsan-apis-part-1-enable-vsan-cluster.html

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;

# define custom options for vm and target host
my %opts = (
   'cluster' => {
      type => "=s",
      help => "Name of vSphere Cluster",
      required => 1,
   },
   'operation' => {
      type => "=s",
      help => "Operation to perform on vSphere Cluster [query|enable|disable]",
      required => 1,
   },
   'autoclaim' => {
      type => "=s",
      help => "Enable or disable auto claiming of disks [enable|disable]",
      required => 0,
      default => "enable",
   },
);

$SIG{__DIE__} = sub{Util::disconnect()};

# read and validate command-line parameters 
Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $operation = Opts::get_option("operation");
my $autoclaim = Opts::get_option("autoclaim");
my $cluster = Opts::get_option("cluster");
my %state = ('enable','true','disable','false');

my $cluster_view = Vim::find_entity_view(view_type => 'ComputeResource', filter => { 'name' => $cluster});

unless($cluster_view) {
	Util::disconnect();
	print "Error: Unable to find vSphere Cluster " . $cluster . "\n";
	exit 1;
}

if($operation eq "query") {
	if(defined($cluster_view->configurationEx->vsanConfigInfo)) {
		print "VSAN Cluster Enabled: " . ($cluster_view->configurationEx->vsanConfigInfo->enabled ? "true" : "false") . "\n";
		if($cluster_view->configurationEx->vsanConfigInfo->enabled) {
			print "VSAN Cluster UUID: " . $cluster_view->configurationEx->vsanConfigInfo->defaultConfig->uuid . "\n";
			print "VSAN Cluster Autoclaim: " . ($cluster_view->configurationEx->vsanConfigInfo->defaultConfig->autoClaimStorage ? "true" : "false") . "\n\n";
			if(defined($cluster_view->configurationEx->vsanHostConfig)) {
				my $vsanHostConfigs = $cluster_view->configurationEx->vsanHostConfig;
				foreach my $vsanHost (@$vsanHostConfigs) {
					my $host = Vim::get_view(mo_ref => $vsanHost->hostSystem, properties => ['name']);	
					my $nodeUuid = ($vsanHost->clusterInfo->nodeUuid ? $vsanHost->clusterInfo->nodeUuid : "N/A");

					print "Host: " . $host->{'name'} . "\n";
					print "Host Node UUID: " . $nodeUuid . "\n";
					print "Host VSAN Enabled: " . ($vsanHost->enabled ? "true" : "false") . "\n";
					print "\n";
				}
			}
		}
	}
} elsif($operation eq "enable") {
	eval {
		print "Enabling VSAN on vSphere cluster: \"" . $cluster . "...\n";
		my $vsanDefaultConfig = VsanClusterConfigInfoHostDefaultInfo->new(autoClaimStorage => $state{$autoclaim});
		my $vsanConfigSpec = VsanClusterConfigInfo->new(enabled => $state{$operation}, defaultConfig => $vsanDefaultConfig);
		my $clusterConfigSpec = ClusterConfigSpecEx->new(vsanConfig => $vsanConfigSpec);
		my $taskRef = $cluster_view->ReconfigureComputeResource_Task(spec => $clusterConfigSpec, modify => 'true');
		my $msg = "\tSuccessfully " . "enabled VSAN on vSphere cluster: \"" . $cluster . "\"\n";
		&getStatus($taskRef,$msg);
	};
	if($@) {
		print "Error: " . $@ . "\n";
		Util::disconnect();
		exit 1;
	}
} elsif($operation eq "disable") {
	eval {
  	print "Disabling VSAN on vSphere cluster: \"" . $cluster . "...\n";
    my $vsanConfigSpec = VsanClusterConfigInfo->new(enabled => $state{$operation});
    my $clusterConfigSpec = ClusterConfigSpecEx->new(vsanConfig => $vsanConfigSpec);
    my $taskRef = $cluster_view->ReconfigureComputeResource_Task(spec => $clusterConfigSpec, modify => 'true');
    my $msg = "\tSuccessfully " . "disabled VSAN on vSphere cluster: \"" . $cluster . "\"\n";
    &getStatus($taskRef,$msg);
  };
  if($@) {
  	print "Error: " . $@ . "\n";
		Util::disconnect();
		exit 1;
	}
} else {
	print "Invalid Selection!\n";
}

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
