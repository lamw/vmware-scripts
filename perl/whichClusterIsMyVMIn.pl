#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://communities.vmware.com/docs/DOC-10439

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

my ($cluster_views,$vmname,$vm_view,$host_view,$hostname);

my %opts = (
        vmname => {
        type => "=s",
        help => "Name of the Virutal Machine",
        required => 1,
        },
);

# validate options, and connect to the server
Opts::add_options(%opts);

# validate options, and connect to the server
Opts::parse();
Opts::validate();
Util::connect();

$vmname = Opts::get_option('vmname');

#verify VM is valid
$vm_view = Vim::find_entity_view(view_type => 'VirtualMachine', filter => {"config.name" => $vmname});

unless (defined $vm_view){
        die "No VM named \"$vmname\" can be found! Check your spelling\n";
}
print "Located VM: \"$vmname\"!\n";

#retrieve the host in which the VM is hosted on
$host_view = Vim::get_view(mo_ref => $vm_view->runtime->host);

unless (defined $host_view){
        die "Unable to retrieve ESX(i) host from \"$vmname\".\n";
}
$hostname = $host_view->name;
print "VM: \"$vmname\" is hosted on \"$hostname\"\n";

$cluster_views = Vim::find_entity_views(view_type => 'ClusterComputeResource');

unless (defined $cluster_views){
        die "No clusters found.\n";     
}

my $found = 0;
my $foundCluster;
foreach(@$cluster_views) {
        my $clustername = $_->name;
        if($found eq 0) {
                my $hosts = Vim::get_views(mo_ref_array => $_->host);
                foreach(@$hosts) {
                        if($_->name eq $hostname) {
                                $found = 1;
                                $foundCluster = $clustername;   
                                last;
                        }
                }
        }
}

if($found) {
        print "VM: \"$vmname\" is located on Cluster: \"$foundCluster\"\n";
} else {
        print "Unable to locate the cluster VM: \"$vmname\" is in\n";
}

Util::disconnect();
