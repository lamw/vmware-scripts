#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://www.virtuallyghetto.com/2012/03/vm-provisioning-on-datastore-clusters.html

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
      help => "Name of cloned VM. Omit to create a new VM.",
      required => 0,
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

# clone mode
if ( defined $clonename ) {
   
   my $vm = Vim::find_entity_view(view_type => 'VirtualMachine', filter => {'name' => $vmname}, properties => ['name']);
   unless($vm) {
       print "Unable to locate VM: $vmname!\n";
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
  
# Create NEW VM mode
} else {
      
   my $vmCfg = VirtualMachineConfigSpec->new(
      name => $vmname,
      memoryMB => 2048,
      numCPUs => 2
   );
   
   
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
