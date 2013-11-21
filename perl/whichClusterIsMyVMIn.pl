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
# http://communities.vmware.com/docs/DOC-10439
# http://engr.ucsb.edu/~duonglt/vmware/

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
