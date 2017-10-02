#!/usr/env perl

# Author: Tim Lapawa
#

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;
use Data::Dumper;

my %opts = (
    cluster => {
        type => "=s",
        help => "The name of a vCenter cluster to query",
        required => 0,
    },
    #virtualmachine => {
    #    type => "=s",
    #    help => "The name of a Virtual Machine to query",
    #    required => 0,
    #},
);


sub waitOnTask {
    my ($taskRef) = @_;
    my $task_view = Vim::get_view(mo_ref => $taskRef);
    my $taskinfo = $task_view->info->state->val;
    my $continue = 1;
    while ($continue) {
        my $info = $task_view->info; if ($info->state->val eq 'success') {
            return $info->result; $continue = 0;
        } elsif ($info->state->val eq 'error') {
            my $soap_fault = SoapFault->new; $soap_fault->name($info->error->fault);
            $soap_fault->detail($info->error->fault);
            $soap_fault->fault_string($info->error->localizedMessage); print color("red") . "\tError:
            $soap_fault\n" . color("reset");
        } sleep 5; $task_view->ViewBase::update_view_data();
    }
}

# cache for host and vm views
my %hosts = ();
my %vms = ();
sub get_vm_name{
    my ($moref) = @_;
    if ( exists $vms{$$moref{value}} ) {
        return $vms{$$moref{value}}->{name};
    }
    
    my $view = Vim::get_view(mo_ref => $moref, properties => ['name']);
    $vms{$moref->{value}} = $view;
    return $view->{name};
} # get_vm_name

sub get_host_name {
    my ($moref) = @_;
    if ( exists $hosts{$$moref{value}} ) {
        return $hosts{$$moref{value}}->{name};
    }
    
    my $view = Vim::get_view(mo_ref => $moref, properties => ['name']);
    $hosts{$moref->{value}} = $view;
    return $view->{name};
} # get_host_name

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();
$SIG{__DIE__} = sub{Util::disconnect()};

my $cluster_name = Opts::get_option('cluster');
my $vm_name = Opts::get_option('virtualmachine');

if (! ($cluster_name xor $vm_name)){
    Uril::disconnect();
    print ("Please select one of virtualmachine or cluster.");
    exit 1;
}

my $cluster_view = undef;
my @vm_views = ();

#if ( $vm_name ne "" ) {
#    my $vm_view = Vim::find_entity_view(view_type => 'VirtualMachine', filter => { 'name' => $vm_name},
#                                             properties => ['name', 'parent'  ]);
#    unless($vm_view) {
#       	Util::disconnect();
#       	print "Error: Unable to find Virtual Machine'" . $cluster_name . "'. Exit(1)!\n";
#       	exit 1;        
#    }
#    $vm_views[0] = $vm_view;
#    
#    $cluster_name =
#}


$cluster_view = Vim::find_entity_view(view_type => 'ClusterComputeResource', filter => { 'name' => $cluster_name},
                                             properties => ['name', 'host'  ]);

unless($cluster_view) {
   	Util::disconnect();
   	print "Error: Unable to find vSphere Cluster '" . $cluster_name . "'. Exit(1)!\n";
   	exit 1;
}
my $num_hosts = @{$cluster_view->{host}};
my $num_vms = 0;

print (" * Checking vSphere Cluster: '".$cluster_name."' with ". $num_hosts ." ESXi hostsystem(s).\n");

my $esxhost_views = Vim::get_views( mo_ref_array => \@{$cluster_view->{host}},
                              view_type => "HostSystem",
                              properties => ['name', 'vm', 'runtime']);                        
                              
my $service_content = Vim::get_service_content();
my $profChecker = Vim::get_view(mo_ref => $service_content->{vmProvisioningChecker});

# Hash to store views references by mo_ref->value; Eg.g 'vm-1123'
my @host_morefs = ();
my @vm_morefs = ();
foreach (@$esxhost_views){
    my $hostview = $_;
    $hosts{$hostview->{mo_ref}->{value}} = $hostview;
    push @host_morefs, $hostview->{mo_ref};

    if (lc ($hostview->{runtime}->{connectionState}->{val}) ne "connected" ){
        print("  * Skipping ESXi host '".$hostview->{name}."'. Not connected.\n");
        next;
    }
    
    if ( $hostview->{runtime}->{inMaintenanceMode} ) {
        print("  * Skipping ESXi host '".$hostview->{name}."'. Maintenance mode.\n");
        next;
    }

    if (!$hostview->{vm}){
        print("  * Skipping ESXi host '".$hostview->{name}."'. Without Virtual Machines.\n");
        next;
    }

    if ($hostview->{vm}){
        push @vm_morefs, @{$hostview->{vm}};
        $num_vms = @{$hostview->{vm}};
    } else {
        $num_vms = 0;
    }
    print("  * Checking ESXi host '".$hostview->{name}."' with ".$num_vms." Virtual Machine(s).\n");
}  # foreach hostsystem


$num_vms = @vm_morefs;
$num_hosts= @host_morefs;
print(" * Query vCenter for vMotion of ".$num_vms." virtual machines and ".$num_hosts." ESXi hosts.\n");
my $results = waitOnTask($profChecker->QueryVMotionCompatibilityEx_Task( vm => \@vm_morefs, host => \@host_morefs ));

#print Dumper($results);
foreach (@$results){
    my $result = $_;
    if( $$result{warning} || $$result{error}){
        my $vm_name = get_vm_name( $result->{vm});
        my $host_name = get_host_name( $result->{host});
        my $reason = '';
        my @messages = ();
        if ($$result{warning}) {
            @messages = @{$result->{warning}};
        } else {
            @messages = @{$result->{error}};
        }

        foreach (@messages){
            $reason = $reason . ref ($_->{fault}). ': '. $_->{localizedMessage};
        }
        print('   * blocking vmotion: vm('.$vm_name.') to host('.$host_name.")\n    - fault(".$reason.")\n");
    } # if error of warning
} # foreach result

Util::disconnect();

