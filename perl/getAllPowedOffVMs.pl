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
# Script: getAllPowedOffVMs.pl
# Require: vCenter
# Input: cluster name
# Return: list of VM(s) that are poweredOff on each ESX(i) host within the specified cluster
# Sample created for http://communities.vmware.com/thread/212317
# http://communities.vmware.com/docs/DOC-10058
################################################################################################

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;
use lib "/usr/lib/vmware-viperl/apps/AppUtil";

my ($cluster_view, $cluster, $cluster_name);

my %opts = (
        cluster => {
        type => "=s",
        help => "The name of a vCenter cluster to disable DRS on",
        required => 1,
        },
);

# validate options, and connect to the server
Opts::add_options(%opts);

# validate options, and connect to the server
Opts::parse();
Opts::validate();
Util::connect();

if ( Opts::option_is_set('cluster') ) {
        $cluster_name = Opts::get_option('cluster');
}

$cluster_view = Vim::find_entity_view(view_type => 'ClusterComputeResource', filter => { name => $cluster_name });

unless (defined $cluster_view){
        die "No cluster found with name $cluster_name.\n";
}

print "Found Cluster: ",$cluster_view->name," \n";
my $hosts = Vim::get_views (mo_ref_array => $cluster_view->host);
foreach my $host (@$hosts) {
        print "\tChecking host: ",$host->name,"\n";
        my $vms = Vim::get_views(mo_ref_array => $host->vm);
        foreach my $vm (@$vms) {
                if($vm->runtime->powerState->val eq 'poweredOff') {
                        print "\t\t",$vm->name," is poweredOff\n";
                }
        }
}

Util::disconnect();
