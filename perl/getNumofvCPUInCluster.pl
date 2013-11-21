#!/usr/bin/perl -w
# Copyright (c) 2009-2010 William Lam All rights reserved.

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
# 08/18/09
# http://communities.vmware.com/docs/DOC-10556
# http://engineering.ucsb.edu/~duonglt/vmware

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
