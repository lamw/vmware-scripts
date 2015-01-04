#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://communities.vmware.com/docs/DOC-10058

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
