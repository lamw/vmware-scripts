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
# 12/02/09
# http://communities.vmware.com/docs/DOC-11581
# http://www.virtuallyghetto.com/

use strict;
use warnings;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
   datacenter => {
      type => "=s",
      help => "Name of Datacenter to search for VM network/MAC Addresses",
      required => 0,
   },
   cluster => {
      type => "=s",
      help => "Name of Cluster to search for VM network/MAC Addresses",
      required => 0,
   },
);

# validate options, and connect to the server
Opts::add_options(%opts);

# validate options, and connect to the server
Opts::parse();
Opts::validate();
Util::connect();

my $datacenter = Opts::get_option('datacenter');
my $cluster = Opts::get_option('cluster');
my $service_content = Vim::get_service_content();
my $apiType = $service_content->about->apiType;
my %vswitch_portgroup_mappping = ();
my ($vmname,$macaddress,$portgroup,$vswitch);

format output =
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<@<<<<<<<<<<<<<<<<<<<<<<<<<@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<@<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$vmname,             $macaddress,           $portgroup,        $vswitch
-------------------------------------------------------------------------------------------------------------------------------
.

$~ = 'output';
($vmname,$macaddress,$portgroup,$vswitch) = ('VM NAME','MAC ADDRESS','PORTGROUP','VSWITCH');
write;

if($datacenter) {
	my $dc_view = Vim::find_entity_view(view_type => 'Datacenter', filter => {name => $datacenter});
	unless($dc_view) {
		Util::disconnect();
		die "Unable to locate Datacenter: \"$datacenter\"!\n";
	}
	print "\nDatacenter: " . $dc_view->name . "\n\n";
	my $cluster_views = Vim::find_entity_views(view_type => 'ClusterComputeResource',begin_entity => $dc_view);
		foreach my $cluster_view (@$cluster_views) {
			my $hosts = Vim::get_views(mo_ref_array => $cluster_view->host);
			foreach my $host_view (@$hosts) {
				&mapPortgroupTovSwitch($host_view);
		                &getVMNetwork($host_view);
		}
	}
}elsif($cluster) {
	my $cluster_view = Vim::find_entity_view(view_type => 'ClusterComputeResource', filter => {name => $cluster});
	unless($cluster_view) {
                Util::disconnect();
                die "Unable to locate Cluster: \"$cluster\"!\n";
        }
	print "\nCluster: " . $cluster_view->name . "\n\n";
	my $hosts = Vim::get_views(mo_ref_array => $cluster_view->host);
	foreach my $host_view (@$hosts) {
		&mapPortgroupTovSwitch($host_view);
                &getVMNetwork($host_view);
        }
} else {
	if($apiType eq 'VirtualCenter') {
		my $host_views = Vim::find_entity_views(view_type => 'HostSystem');
		foreach my $host_view (@$host_views) {
			&mapPortgroupTovSwitch($host_view);
	                &getVMNetwork($host_view);
	        }
	} else {
		my $host_view = Vim::find_entity_view(view_type => 'HostSystem');
		print "\nHost: " . $host_view->name . "\n\n";
		&mapPortgroupTovSwitch($host_view);
		&getVMNetwork($host_view);	
	}
}

Util::disconnect();

sub mapPortgroupTovSwitch {
	my ($host) = @_;

	my $networkSys = Vim::get_view(mo_ref => $host->configManager->networkSystem);
	my $portgroups = $networkSys->networkConfig->portgroup;

	foreach(@$portgroups) {
		if(defined($_->spec)) {
			$vswitch_portgroup_mappping{$_->spec->name} = $_->spec->vswitchName;
		}
	}	
}

sub getVMNetwork {
	my ($host) = @_;
		my $vms = Vim::get_views(mo_ref_array => $host->vm, properties => ["config.name","network","config.hardware.device"]);
		foreach(sort {$a->{'config.name'} cmp $b->{'config.name'}} @$vms) {
			my $vmNetworks = Vim::get_views(mo_ref_array => $_->network);
			my %dvswitch_portgroup_mapping = ();
			foreach(@$vmNetworks) {
				if($_->isa("DistributedVirtualPortgroup")) {
					my $dvs = Vim::get_view(mo_ref => $_->config->distributedVirtualSwitch, properties => ['name']);
					$dvswitch_portgroup_mapping{$_->key} = $dvs->{'name'} . "=" . $_->name;
				}
			}

			$vmname = $_->{'config.name'};
			my $devices = $_->{'config.hardware.device'};
			foreach(@$devices) {
				if($_->isa("VirtualEthernetCard")) {
					$macaddress = $_->macAddress;
					if($_->backing->isa("VirtualEthernetCardDistributedVirtualPortBackingInfo")) {
						if(defined($_->backing->port->portgroupKey) && defined($dvswitch_portgroup_mapping{$_->backing->port->portgroupKey})) {
							($vswitch,$portgroup) = split("=",$dvswitch_portgroup_mapping{$_->backing->port->portgroupKey});
						} else {
							$vswitch = "UNKNOWN";
							$portgroup = "UNKNOWN";
						}
					} elsif(defined($_->backing->network)) {
						my $pg_view = Vim::get_view(mo_ref => $_->backing->network,properties => ['name']);
                                                $portgroup = $pg_view->{'name'};

						if(defined($portgroup) && defined($vswitch_portgroup_mappping{$portgroup})) {
							$vswitch = $vswitch_portgroup_mappping{$portgroup};
						} else {
							$vswitch = "UNKNOWN";
						}
					} else {
						$vswitch = "UNKNOWN";
						$portgroup = "UNKNOWN";
					}
					write;
				}
			}
		}
}
