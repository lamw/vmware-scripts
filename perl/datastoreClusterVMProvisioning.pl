#!/usr/bin/perl -w
# Copyright (c) 2009-2012 William Lam All rights reserved.

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
# http://www.virtuallyghetto.com/

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;

my %opts = (
   vmname => {
      type => "=s",
      help => "Name of VM to clone to datastore cluster",
      required => 1,
   },
   datastorecluster => {
      type => "=s",
      help => "Name of datastore cluster",
      required => 1,
   },
   clonename => {
      type => "=s",
      help => "Name of cloned VM",
      required => 1,
   },
   vmfolder => {
      type => "=s",
      help => "Name of vCenter VM folder",
      required => 1,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $vmname = Opts::get_option('vmname');
my $clonename = Opts::get_option('clonename');
my $datastorecluster = Opts::get_option('datastorecluster');
my $vmfolder = Opts::get_option('vmfolder');

# get VM view
my $vm = Vim::find_entity_view(view_type => 'VirtualMachine', filter => {'name' => $vmname}, properties => ['name']);
unless($vm) {
	print "Unable to locate VM: $vmname!\n";
	Util::disconnect();
	exit 1;
}

# get datastore cluster view
my $dscluster = Vim::find_entity_view(view_type => 'StoragePod', filter => {'name' => $datastorecluster}, properties => ['name']);
unless($dscluster) {
        print "Unable to locate datastore cluster: $dscluster!\n";
        Util::disconnect();
        exit 1;
}

# get VM Folder view
my $folder = Vim::find_entity_view(view_type => 'Folder', filter => {'name' => $vmfolder}, properties => ['name']);
unless($folder) {
        print "Unable to locate VM folder: $vmfolder!\n";
        Util::disconnect();
        exit 1;
}

# get storage rsc mgr
my $storageMgr = Vim::get_view(mo_ref => Vim::get_service_content()->storageResourceManager);

# create storage spec
my $podSpec = StorageDrsPodSelectionSpec->new(storagePod => $dscluster);
my $location = VirtualMachineRelocateSpec->new();
my $cloneSpec = VirtualMachineCloneSpec->new(powerOn => 'false', template => 'false', location => $location);
my $storageSpec = StoragePlacementSpec->new(type => 'clone', cloneName => $clonename, folder => $folder, podSelectionSpec => $podSpec, vm => $vm, cloneSpec => $cloneSpec);

eval {
	my ($result,$key,$task,$msg);
	$result = $storageMgr->RecommendDatastores(storageSpec => $storageSpec);

	#reetrieve SDRS recommendation 
	$key = eval {$result->recommendations->[0]->key} || [];

	#if key exists, we have a recommendation and need to apply it
	if($key) {
		print "Cloning \"$vmname\" to \"$clonename\" onto \"$datastorecluster\"\n";
		$task = $storageMgr->ApplyStorageDrsRecommendation_Task(key => [$key]);
		$msg = "\tSuccesfully cloned VM!";
		&getStatus($task,$msg);
	} else {
		print Dumper($result);
		print "Uh oh ... something went terribly wrong and we did not get back SDRS recommendation!\n";
	}
};
if($@) {
	print "Error: " . $@ . "\n";
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
                        return $info->result;
                        $continue = 0;
                } elsif ($info->state->val eq 'error') {
                        my $soap_fault = SoapFault->new;
                        $soap_fault->name($info->error->fault);
                        $soap_fault->detail($info->error->fault);
                        $soap_fault->fault_string($info->error->localizedMessage);
                        die "$soap_fault\n";
                }
                sleep 2;
                $task_view->ViewBase::update_view_data();
        }
}

=head1 NAME

datastoreClusterVMProvisioning.pl - Script to clone VMs onto datastore cluster in vSphere 5

=head1 Examples

=over 4

=item List available datastore clusters

=item

./datastoreClusterVMProvisioning.pl --server [VCENTER_SERVER] --username [USERNAME] --vmname [VM_TO_CLONE] --clonename [NAME_OF_NEW_VM] --vmfolder [VM_FOLDER] --datastorecluster [DATASTORE_CLUSTER] 

=item

=back

=head1 SUPPORT

vSphere 5.0

=head1 AUTHORS

William Lam, http://www.virtuallyghetto.com/

=cut
