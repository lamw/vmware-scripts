#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://www.virtuallyghetto.com/2012/03/vm-provisioning-on-datastore-clusters.html
#
# 2017-06 Added Create VM functionality by Tim Lapawa  git@lapawa.de
#

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
   vmnetwork => {
      type => "=s",
      help => "Name of Network to connect new VM to.",
      required => 0,
   },
   esxcluster => {
      type => "=s",
      help => "Name of vSphere Cluster to provision new VM in.",
      required => 0,
   }
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $vmname = Opts::get_option('vmname');
my $clonename = Opts::get_option('clonename');
my $datastorecluster = Opts::get_option('datastorecluster');
my $vmfolder = Opts::get_option('vmfolder');
my $vmnetworkname = Opts::get_option('vmnetwork');
my $esxclustername = Opts::get_option('esxcluster');

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
my $storageSpec = undef;

if ( defined $clonename ) {
   
   my $vm = Vim::find_entity_view(view_type => 'VirtualMachine', filter => {'name' => $vmname}, properties => ['name']);
   unless($vm) {
       print "Unable to locate VM: $vmname!\n";
       Util::disconnect();
       exit 1;
   }
  
  # create storage spec
  my $podSpec = StorageDrsPodSelectionSpec->new(storagePod => $dscluster);
  my $location = VirtualMachineRelocateSpec->new();
  my $cloneSpec = VirtualMachineCloneSpec->new(powerOn => 'false'
                                               , template => 'false'
                                               , location => $location
                                               );
  $storageSpec = StoragePlacementSpec->new(type => 'clone'
                                              , cloneName => $clonename
                                              , folder => $folder
                                              , podSelectionSpec => $podSpec
                                              , vm => $vm
                                              , cloneSpec => $cloneSpec
                                              ); 
  
# create mode  
} else {

   unless($vmnetworkname) {
        print "Unable to find network!\n";
        Util::disconnect();
        exit 1;
   }
   
   my $esxcluster = Vim::find_entity_view(view_type => 'ClusterComputeResource', filter => {'name' => $esxclustername}, properties => ['resourcePool']);
   unless($esxcluster){
      print "Failed to find esxcluster($esxclustername)!\n";
      Util::disconnect();
      exit 1;
   }
   
   my $resourcepool = $esxcluster->resourcePool;
   
      
   my $diskBacking = VirtualDiskFlatVer2BackingInfo->new(
                           fileName        => '',
                           diskMode        => 'persistent',
                           thinProvisioned => 'true',
                           eagerlyScrub    => 'false',
                         );
   my $podDiskLocator = PodDiskLocator->new(
      diskId => -47,
      diskBackingInfo => $diskBacking,
   );
   
   my $vmPodConfigForPlacement = VmPodConfigForPlacement->new(
      storagePod => $dscluster,
      disk       => [$podDiskLocator],
   );
      
   
   my $cdromCfg = VirtualDeviceConfigSpec->new(
      operation => VirtualDeviceConfigSpecOperation->new('add'),
      device => VirtualCdrom->new(
         key     => -44,
         backing => VirtualCdromRemotePassthroughBackingInfo->new(
                     deviceName=> '',
                     exclusive => 'false',
                    ),
         connectable => VirtualDeviceConnectInfo->new(
                        startConnected    => 'false',
                        allowGuestControl => 'true',
                        connected         => 'false',
                     ),
         controllerKey => 201,
         unitNumber    => 0,
      )
   );
   
   my $scsiCfg = VirtualDeviceConfigSpec->new(
                     operation => VirtualDeviceConfigSpecOperation->new('add'),
                     device    => ParaVirtualSCSIController->new(
                                    key       => -45,
                                    busNumber => 0,
                                    sharedBus => VirtualSCSISharing->new('noSharing')
                                  ),
                 );
   
   my $netCfg = VirtualDeviceConfigSpec->new(
                  operation => VirtualDeviceConfigSpecOperation->new('add'),
                  device    => VirtualVmxnet3->new(
                                 key         => -46,
                                 backing     => VirtualEthernetCardNetworkBackingInfo->new(
                                                   deviceName => $vmnetworkname
                                                ),
                                 connectable => VirtualDeviceConnectInfo->new(
                                                   startConnected    => 'true',
                                                   allowGuestControl => 'true',
                                                   connected         => 'true',
                                                ),
                                 addressType => 'generated',
                                 wakeOnLanEnabled => 'true',
                               ),
                );
   my $diskCfg = VirtualDeviceConfigSpec->new(
                     operation     => VirtualDeviceConfigSpecOperation->new('add'),
                     fileOperation => VirtualDeviceConfigSpecFileOperation->new('create'),
                     device        => VirtualDisk->new(
                                          key     => -47,
                                          backing => $diskBacking,
                                          #backing => VirtualDiskFlatVer2BackingInfo->new(
                                          #   fileName        => '',
                                          #   diskMode        => 'persistend',
                                          #   thinProvisioned => 'true',
                                          #   eagerlyScrub    => 'false',
                                          #),
                                          controllerKey => -45,
                                          unitNumber    =>  0,
                                          capacityInKB  =>  16777216,
                                       ),
                  );

   my $vmCfg = VirtualMachineConfigSpec->new(
      name     => $vmname,
      version  => "vmx-08",
      guestId  => "rhel6_64Guest",
      files    => VirtualMachineFileInfo->new(
                     vmPathName => ""
                  ),
      numCPUs  => 2,
      memoryMB => 2048,
      deviceChange => [ $cdromCfg, $scsiCfg, $netCfg, $diskCfg ],
      firmware => "bios",
   );
  
   
   my $podSelectionSpec = StorageDrsPodSelectionSpec->new(
      storagePod => $dscluster,
      initialVmConfig => [ $vmPodConfigForPlacement ],
   );
   #$podSelectionSpec->initialVmConfig->[0] = $vmPodConfigForPlacement;
  

   $storageSpec = StoragePlacementSpec->new(
      type             => 'create',
      podSelectionSpec => $podSelectionSpec,
      configSpec       => $vmCfg,
      resourcePool     => $resourcepool,    
      folder           => $folder,
   );
}
  
  
eval {
    my ($result,$key,$task,$msg);
     # get storage rsc mgr
    my $storageMgr = Vim::get_view(mo_ref => Vim::get_service_content()->storageResourceManager);
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

datastoreClusterVMProvisioning.pl - Script to clone and create VMs onto datastore cluster in vSphere 5 and above

=head1 Examples

=over 4

=item Clone an existing virtual machine:

./datastoreClusterVMProvisioning.pl --server [VCENTER_SERVER] --username [USERNAME] --vmname [VM_TO_CLONE] --clonename [NAME_OF_NEW_VM] --vmfolder [VM_FOLDER] --datastorecluster [DATASTORE_CLUSTER] 



=item Create a new virtual machine:

./datastoreClusterVMProvisioning.pl --server [VCENTER_SERVER] --username [USERNAME] --vmname [VM_TO_CREATE] --vmfolder [VM_FOLDER] --datastorecluster [DATASTORE_CLUSTER] --esxcluster [ESX_CLUSTER] --vmnetwork [NETWORK_NAME]

This will create a default vm setup with 2GB Ram, 2 vCPUs and one thin provisioned disk with 16GB.

=back

=head1 SUPPORT

vSphere 5.0, vSphere 5.5, vSphere 6.0, vSphere 6.5

=head1 AUTHORS

=over 4

=item William Lam, http://www.virtuallyghetto.com/

=item 2017 Tim Lapawa

=back

=cut
