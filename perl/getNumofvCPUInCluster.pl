#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://communities.vmware.com/docs/DOC-10556

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;
use VMware::VIExt;

my %opts = (
   cluster => {
      type => "=s",
      help => "Name of Cluster to search",
      required => 1,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $cluster = Opts::get_option('cluster');
my @nonshared_datastores;
my ($cluster_view,$host_views,$vms);

$cluster_view = Vim::find_entity_view(view_type => 'ClusterComputeResource', filter => { name => $cluster});

unless($cluster_view) {
	die "Unable to locate cluster name \"$cluster\"!";
}

print "This could take a few minutes depending on the size of the cluster ...\n\n";

my $numvCPU;
print "Cluster: " . $cluster_view->name . "\n";
$host_views = Vim::get_views(mo_ref_array => $cluster_view->host);
foreach(@$host_views) {
	my $localnumvCPU;
	print "\tHost: " . $_->name . "\n";
	if($_->runtime->connectionState->val eq 'connected' && $_->runtime->inMaintenanceMode eq 0) {
		my $optMgr = Vim::get_view(mo_ref => $_->configManager->advancedOption);
		my ($name, $value) = VIExt::get_advoption($optMgr,"Misc.RunningVCpuLimit");
		print "\t\tMisc.RunningVCpuLimit: " . $value . "\n";
		$vms = Vim::get_views(mo_ref_array => $_->vm);
		foreach(@$vms) {
			$numvCPU += $_->summary->config->numCpu;	
			$localnumvCPU += $_->summary->config->numCpu;
		}
		print "\t\t# of vCPU on host: " . $localnumvCPU . "\n";
	} else {
	print "\t\tHost is either 'disconnected','notResponding' or in 'Maint Mode'\n"
	}
}
print "\t# of vCPU: " . $numvCPU . "\n\n";

Util::disconnect();
