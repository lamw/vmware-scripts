#
# Copyright (c) 2007 VMware, Inc.  All rights reserved.
#

use 5.006001;
use strict;
use warnings;

our $VERSION = '0.1';


##################################################################################
package VMUtils;


# This subroutine finds the VMs based on the selection criteria.
# Input Parameters:
# ----------------
# entity        : 'VirtualMachine'
# name          : Virtual machine name
# datacenter    : Datacenter name
# folder        : Folder name
# pool          : Reource pool name
# host          : host name
# filter_hash   : The hash map which contains the filter criteria for virtual machines
#                 based on the machines attributes like guest OS, powerstate etc.
# 
# Output:
# ------
# It returns an array of virtual machines found as per the selection criteria

sub get_vms {
   my ($entity, $name, $datacenter, $folder, $pool, $host, %filter_hash) = @_;
   my $begin;
   my $entityViews;
   my %filter = %filter_hash;
   my $vms;

   if (defined $datacenter) {
      $begin =
         Vim::find_entity_views (view_type => 'Datacenter',
                                filter => {name => $datacenter});
                                
      unless (@$begin) {
         Util::trace(0, "Datacenter $datacenter not found.\n");
         return;
      }

     if ($#{$begin} != 0) {
         Util::trace(0, "Datacenter <$datacenter> not unique.\n");
         return;
      }

   }
   else {
      @$begin = Vim::get_service_content()->rootFolder;
   }
   if (defined $folder) {
      my $vms = Vim::find_entity_views (view_type => 'Folder',
                                        begin_entity => @$begin,
                                        filter => {name => $folder});
      unless (@$vms) {
         Util::trace(0, "Folder <$folder> not found.\n");
         return;
      }
      if ($#{$vms} != 0) {
         Util::trace(0, "Folder <$folder> not unique.\n");
         return;
      }
      @$begin = shift (@$vms);
   }
   if (defined $pool) {
      $vms = Vim::find_entity_views (view_type => 'ResourcePool',
                                     begin_entity => @$begin,
                                     filter => {name => $pool});
      unless (@$vms) {
         Util::trace(0, "Resource pool <$pool> not found.\n");
         return;
      }
      if ($#{$vms} != 0) {
         Util::trace(0, "Resource pool <$pool> not unique.\n");
         return;
      }
      @$begin = shift (@$vms);
   }
   if (defined $host) {
      my $hostView = Vim::find_entity_view (view_type => 'HostSystem',
                                            filter => {'name' => $host});
      unless ($hostView) {
         Util::trace(0, "Host $host not found.");
         return;
      }
      $filter{'name'} = $name if (defined $name);
      my $vmviews = Vim::find_entity_views (view_type => $entity,
                                             begin_entity => @$begin,
                                             filter => \%filter);
      my @retViews;
      foreach (@$vmviews) {
         my $host = Vim::get_view(mo_ref => $_->runtime->host);
         my $hostname = $host->name;
         if($hostname eq $hostView->name) {
            push @retViews,$_;
         }
      }
      if (@retViews) {
         return \@retViews;
      }
      else {
         Util::trace(0, "No Virtual Machine found.\n");
         return;
      }
   }
   elsif (defined $name) {
      $filter{'name'} = $name if (defined $name);
      $entityViews = Vim::find_entity_views (view_type => $entity,
                                             begin_entity => @$begin,
                                             filter => \%filter);
      unless (@$entityViews) {
         Util::trace(0, "Virtual Machine $name not found.\n");
         return;
      }
   }
   else {
      $entityViews =
         Vim::find_entity_views (view_type => $entity,
                                 begin_entity => @$begin,filter => \%filter);
       unless (@$entityViews) {
          Util::trace(0, "No Virtual Machine found.\n");
          return;
       }
   }
   
    if ($entityViews) {return \@$entityViews;}
   else {return 0;}
}


# This subroutine constructs the customization spec for virtual machines.
# Input Parameters:
# ----------------
# filename      : The location of the input XML file. This file contains the 
#                 various properties for customization spec 
#
# Output:
# ------
# It returns the customization spec as per the input XML file

sub get_customization_spec {
   my ($filename) = @_;
   my $parser = XML::LibXML->new();
   my $tree = $parser->parse_file($filename);
   my $root = $tree->getDocumentElement;
   my @cspec = $root->findnodes('Customization-Spec');

   # Default Values
   my $custType = "Win";
   my $autologon = 1;
   my $computername = "compname";
   my $timezone = 190;
   my $linuxTimezone = "America/Chicago";
   my $utcClock = 1;
   my $username;
   my $userpassword;
   my $domain;
   my $fullname;
   my $autoMode = "perServer";
   my $autoUsers = 5;
   my $organization_name;
   my $productId = "XXXX-XXXX-XXXX-XXXX-XXXX";
   my $customization_fixed_ip;
   my $ip;
   my @gateway;
   my @dnsServers;
   my @dnsSearch;
   
   my $subnet;
   my $primaryWINS;
   my $secondaryWINS;
   
  
   foreach (@cspec) {
      if ($_->findvalue('Cust-Type')) {
         $custType = $_->findvalue('Cust-Type');
      }
      if ($_->findvalue('Auto-Logon')) {
         $autologon = $_->findvalue('Auto-Logon');
      }
      if ($_->findvalue('Virtual-Machine-Name')) {
         $computername = $_->findvalue('Virtual-Machine-Name');
      }
      if ($_->findvalue('Timezone')) {
         $timezone = $_->findvalue('Timezone');
      }
      if ($_->findvalue('Linux-Timezone')) {
         $linuxTimezone = $_->findvalue('Linux-Timezone');
      }
      if ($_->findvalue('UTC-Clock')) {
         $utcClock = $_->findvalue('UTC-Clock');
      }
      if ($_->findvalue('Domain')) {
         $domain = $_->findvalue('Domain');
      }
      if ($_->findvalue('Domain-User-Name')) {
         $username = $_->findvalue('Domain-User-Name');
      }
      if ($_->findvalue('Domain-User-Password')) {
         $userpassword = $_->findvalue('Domain-User-Password');
      }
      if ($_->findvalue('Full-Name')) {
         $fullname = $_->findvalue('Full-Name');
      }
      if ($_->findvalue('AutoMode')) {
         $autoMode = $_->findvalue('AutoMode');
      }
      if ($_->findvalue('AutoUsers')) {
         $autoUsers = $_->findvalue('AutoUsers');
      }
   # bug 299843 fix start
      if ($_->findvalue('Orgnization-Name')) {
         $organization_name = $_->findvalue('Orgnization-Name');
      }
   # bug 299843 fix end
      if ($_->findvalue('ProductId')) {
         $productId = $_->findvalue('ProductId');
      }
      if ($_->findvalue('IP0')) {
         $ip = $_->findvalue('IP0');
      }
      if ($_->findvalue('IP0Gateway')) {
         @gateway = split (':', $_->findvalue('IP0Gateway'));
      }
      
      if ($_->findvalue('IP0Subnet')) {
         $subnet = $_->findvalue('IP0Subnet');
      }
      
      if ($_->findvalue('IP0primaryWINS')) {
         $primaryWINS = $_->findvalue('IP0primaryWINS');
      }
      if ($_->findvalue('IP0secondaryWINS')) {
         $secondaryWINS = $_->findvalue('IP0secondaryWINS');
      }
      if ($_->findvalue('dnsServers')) {
         @dnsServers = split (':', $_->findvalue('dnsServers'));
      }
      if ($_->findvalue('dnsSearch')) {
         @dnsSearch = split (':', $_->findvalue('dnsSearch'));
      }
      
      
   }
  
   my $customization_global_settings = CustomizationGlobalIPSettings->new();
   $customization_global_settings->{'dnsServerList'} = \@dnsServers;
   $customization_global_settings->{'dnsSuffixList'} = \@dnsSearch;
   
   my $customization_identity_settings = CustomizationIdentitySettings->new();

   my $password =
      CustomizationPassword->new(plainText=>"true", value=> $userpassword );

   my $cust_identification =
      CustomizationIdentification->new(domainAdmin => $username,
                                       domainAdminPassword => $password,
                                       joinDomain => $domain);

   my $cust_gui_unattended =
      CustomizationGuiUnattended->new(autoLogon => $autologon,
                                      autoLogonCount => 0,
                                      timeZone => $timezone);

   my $cust_name = CustomizationFixedName->new (name => $computername);
   my $cust_user_data =
      CustomizationUserData->new(computerName => $cust_name,
                                 fullName => $fullname,
                                 orgName => $organization_name,
                                 productId => $productId);
   
   my $customLicenseDataMode = new CustomizationLicenseDataMode($autoMode);
   my $licenseFilePrintData = 
      CustomizationLicenseFilePrintData->new(autoMode => $customLicenseDataMode,
                                             autoUsers => $autoUsers);
   my $cust_prep;

   # test for Linux or Windows customization
   if ( $custType eq "Win" ) {
     $cust_prep = 
      CustomizationSysprep->new(guiUnattended => $cust_gui_unattended,
                                identification => $cust_identification,
                                licenseFilePrintData => $licenseFilePrintData,
                                userData => $cust_user_data);
   } else {
     $cust_prep =
      CustomizationLinuxPrep->new(domain => $domain,
                                hostName => $cust_name,
                                hwClockUTC => $utcClock,
                                timeZone => $linuxTimezone);
   }

   if ( defined $ip && $ip ne "dhcp" ) {
      $customization_fixed_ip = CustomizationFixedIp->new(ipAddress=>$ip);
   } else {
      $customization_fixed_ip = CustomizationDhcpIpGenerator->new();
   }
   
   
   my $cust_ip_settings =
      CustomizationIPSettings->new(ip => $customization_fixed_ip,
                                   gateway => \@gateway,
                                   dnsServerList => \@dnsServers,
                                   subnetMask => $subnet,
                                   dnsDomain => $domain,
                                   primaryWINS => $primaryWINS,
                                   secondaryWINS => $secondaryWINS);

   my $cust_adapter_mapping =
      CustomizationAdapterMapping->new(adapter => $cust_ip_settings);

   my @cust_adapter_mapping_list = [$cust_adapter_mapping];

   my $customization_spec =
      CustomizationSpec->new (identity=>$cust_prep,
                              globalIPSettings=>$customization_global_settings,
                              nicSettingMap=>@cust_adapter_mapping_list);
   return $customization_spec;
}


# This subroutine migrate the virtual machine to same datastore.
# Input Parameters:
# ----------------
# vm:                   Managed Object of virtual machine.
# pool:                 Managed Object of resource pool
# targethostview:       Managed Object of target host
# sourcehostview:       Managed Object of source host
# priority:             Priorty of migration task
# state:                Allowed state of virtual machine for the operation.
#

sub migrate_virtualmachine {
   my %args = @_;

   my $vm = $args{vm};
   my $pool = $args{pool};
   my $targethostview = $args{targethostview};
   my $priority = $args{priority};
   my $state = $args{state};

   Util::trace(0,"Migrating the virtual machine ". $vm->name . "\n");
   eval {
      $vm->MigrateVM(host => $targethostview,
                    pool => $pool,
                    priority => VirtualMachineMovePriority->new($priority),
                    state => VirtualMachinePowerState->new($state));
      Util::trace(0, "Virtual Machine ".$vm->name." sucessfully migrated to host "
                           . $targethostview->name . "\n\n");
   };
   if ($@) {
      if (ref($@) eq 'SoapFault') {
         if (ref($@->detail) eq 'InvalidPowerState') {
            Util::trace(0,"The attempted operation cannot be performed in the "
                          ."current state (Powered On).\n\n");
         }
         elsif (ref($@->detail) eq 'SnapshotCopyNotSupported') {
            Util::trace(0,"Migration of virtual machines with snapshots is not "
                          ."supported between the source and destination.\n\n");
         }
         elsif (ref($@->detail) eq 'NotSupported') {
            Util::trace(0,"The operation is not supported on the Virtual Machine.\n\n");
         }
         elsif (ref($@->detail) eq 'InvalidState') {
            Util::trace(0,"Operation cannot be performed because of the "
                          ."virtual machine's current state.\n\n");
         }
         elsif (ref($@->detail) eq 'VmConfigFault') {
            Util::trace(0,"virtual machine is not compatible with the "
                        . " destination host.\n\n");
         }
         elsif (ref($@->detail) eq 'InvalidArgument') {
            Util::trace(0,"target host and target pool are not associated with "
			             ."the same compute resource .\n\n");
         }
         else {
            Util::trace(0, "Fault " . $@);
         }
      }
      else {
         Util::trace(0, "Fault " . $@);
      }
   }
}


# This subroutine relocate the virtual machine to different datastore.
# Input Parameters:
# ----------------
# vm:                   Managed Object of virtual machine.
# pool:                 Managed Object of resource pool
# targethostview:       Managed Object of target host
# sourcehostview:       Managed Object of source host
# datastore:            Managed object of datastore
#

sub relocate_virtualmachine {
   my %args = @_;

   my $vm = $args{vm};
   my $pool = $args{pool};
   my $targethostview = $args{targethostview};
   my $datastore = $args{datastore};
   my $sourcehostview = $args{sourcehostview};
   
   my $relocate_spec = VirtualMachineRelocateSpec->new (datastore => $datastore,
                                                              host => $targethostview,
                                                              pool => $pool);
   Util::trace(0,"Relocating the virtual machine ". $vm->name . "\n");
   eval {
      $vm->RelocateVM(spec => $relocate_spec);
      Util::trace(0, "Virtual Machine ".$vm->name." sucessfully relocated from host "
                     . $sourcehostview->name . " to host "
                     . $targethostview->name."\n\n");
   };
   if ($@) {
      if (ref($@) eq 'SoapFault') {
         if (ref($@->detail) eq 'InvalidPowerState') {
            Util::trace(0,"The attempted operation cannot be performed in the "
                          ."current state (Powered On).\n\n");
         }
         elsif (ref($@->detail) eq 'SnapshotCopyNotSupported') {
            Util::trace(0,"Migration of virtual machines with snapshots is not "
                          ."supported between the source and destination.\n\n");
         }
         elsif (ref($@->detail) eq 'NotSupported') {
            Util::trace(0,"The operation is not supported on the Virtual Machine.\n\n");
         }
         elsif (ref($@->detail) eq 'InvalidState') {
            Util::trace(0,"Operation cannot be performed because of the "
                          ."virtual machine's current state.\n\n");
         }
         elsif (ref($@->detail) eq 'VmConfigFault') {
            Util::trace(0,"virtual machine is not compatible with the destination host.\n\n");
         }
         else {
            Util::trace(0, "Fault " . $@);
         }
      }
      else {
         Util::trace(0, "Fault " . $@);
      }
   }   
}

# This subroutine find the hardware device on virtual machine.
# Input Parameters:
# ----------------
# vm:                   Managed Object of virtual machine.
# controller:           controller object for this device
#
# Output: Returns the device data object, if found.

sub find_device {
   my %args = @_;
   my $vm = $args{vm};
   my $name = $args{controller};
   
   my $devices = $vm->config->hardware->device;
   foreach my $device (@$devices) {
      return $device if ($device->deviceInfo->label eq $name);
   }
   return undef;
}

# This subroutine generates the filename for virtual disk
# ----------------
# vm:                   Managed Object of virtual machine.
# filename:             Filename of virtual disk.
#
# Output: Returns the complete file name of the virtual disk.

sub generate_filename {
   my %args = @_;
   my $vm = $args{vm};
   my $name = $args{filename};
   $name = $vm->name."/".$name;
   my $fileName = '';
   my $path = $vm->config->files->vmPathName;
   $path =~ /^(\[.*\])/;
   $fileName = "$1/$name";
   $fileName .= ".vmdk" unless ($fileName =~ /\.vmdk$/);
   return $fileName;
}

# This subroutine returns the diskmode.
# valid combinations are 'persistent', 'independent_persistent'
#, and 'independent_nonpersistent'
sub get_diskmode {
   my %args = @_;
   my $nopersist = $args{nopersist};
   my $independent = $args{independent};
   
   my $nonPersistent = $nopersist;
   my $diskMode = ($independent) ? 'independent' : '';
   if ($diskMode eq 'independent') {
      $diskMode .= ($nonPersistent) ? '_nonpersistent' : '_persistent';
   }
   else {
      $diskMode = 'persistent';
   }
   return $diskMode;
}

# This subroutine returns the virtual disk spec for creating virtual disk.
# Input Parameters:
# ----------------
# vm:                   Managed Object of virtual machine.
# fileName:             Name of file name for virtual disk
# diskMode:             Disk persistence mode
# controllerKey:        Denotes the controller object for this device
# unitNumber:           Unit number of this virtual disk on its controller
# size:                 Size of virtual disk
# backingtype:          Backing type of the virtual disk
#
# Output: Returns the virtual disk spec object.

sub get_vdisk_spec {
   my %args = @_;
   my $vm = $args{vm};
   my $diskMode = $args{diskMode};
   my $fileName = $args{fileName};
   my $controllerKey = $args{controllerKey};
   my $unitNumber = $args{unitNumber};
   my $size = $args{size};
   my $backingtype = $args{backingtype};
   my $disk_backing_info;

   if($backingtype eq "regular") {
      $disk_backing_info = VirtualDiskFlatVer2BackingInfo->new(diskMode => $diskMode,
                                                               fileName => $fileName);
   }
   #Require a non-ESX physical disk
   elsif($backingtype eq "rdm") {
      my $host_view;
      if(defined $vm->runtime->host) {
         $host_view = Vim::get_view(mo_ref => $vm->runtime->host);
      }
      else {
         Util::trace(0,"No host found for the virtual machine");
         return;
      }      
      my $host_storage_system = $host_view->config;
      my $lunId = $host_storage_system->storageDevice->scsiLun->[0]->uuid;	  
      my $deviceName = $host_storage_system->storageDevice->scsiLun->[0]->deviceName;
      $disk_backing_info = VirtualDiskRawDiskMappingVer1BackingInfo->new(compatibilityMode => "physical",
                                                                         deviceName => $deviceName,
                                                                         lunUuid => $lunId,
                                                                         fileName => $fileName);
   }
   else {
      Util::trace(0,"Invalid Disk Backing Info Specified");
      return;
   }

   my $disk = VirtualDisk->new(controllerKey => $controllerKey,
                               unitNumber => $unitNumber,
                               key => -1,
                               backing => $disk_backing_info,
                               capacityInKB => $size);

   my $devspec = VirtualDeviceConfigSpec->new(operation => VirtualDeviceConfigSpecOperation->new('add'),
                                              device => $disk,
                                              fileOperation => VirtualDeviceConfigSpecFileOperation->new('create'));
   return $devspec;
}


# This subroutine adds a virtual disk to a virtual machine.
# Input Parameters:
# ----------------
# vm:                  Managed Object of virtual machine.
# devspec:             Config spec virtual disk
#

sub add_virtualdisk {
   my %args = @_;
   my $vm = $args{vm};
   my $devspec = $args{devspec};
   
   my $vmspec = VirtualMachineConfigSpec->new(deviceChange => [$devspec] );
   eval {
      $vm->ReconfigVM( spec => $vmspec );
      Util::trace(0,"Virtual Disk created.\n");
   };
   if ($@) {
      if (ref($@) eq 'SoapFault') {
         if (ref($@->detail) eq 'FileAlreadyExists') {
            Util::trace(0,"Operation failed because file already exists.");
         }
         elsif (ref($@->detail) eq 'InvalidName') {
            Util::trace(0,"If the specified name is invalid.");
         }
         elsif (ref($@->detail) eq 'InvalidDeviceBacking') {
            Util::trace(0,"Incompatible device backing specified for device.");
         }
         elsif (ref($@->detail) eq 'InvalidDeviceSpec') {
            Util::trace(0,"Invalid backing info spec.");
         }		 
         elsif (ref($@->detail) eq 'InvalidPowerState') {
            Util::trace(0,"Attempted operation cannot be performed on the current state.");
         }
         elsif (ref($@->detail) eq 'GenericVmConfigFault') {
            Util::trace(0,"Unable to configure virtual device.");
         }
         elsif (ref($@->detail) eq 'NoDiskSpace') {
            Util::trace(0,"Insufficient disk space on datastore.");
         }
         else {
            Util::trace(0,"Falut : " . $@);
         }
      }
      else {
         Util::trace(0,"Falut : " . $@);
      }
   }
}


# This subroutine creates the configuration spec for NIC adapter
# based on the operation.
# Input Parameters:
# ----------------
# vm_view    : Managed object of the virtual machine.
# network    : NIC adapter name.
# operation		: The Virtual Device Config Spec operation.
# flagvalue  : Value of the connectAtPowerOn flag. (true/false)
#              Required only for 'setflag' operation.
#
# The possible values for input parameter 'operation' can be
# 'add'        - to add an NIC adapter,
# 'remove'     - to remove an NIC adapter,
# 'setflag'    - to set the connectAtPowerOn flag for an NIC adapter,
# 'connect'    - to connect an NIC adapter,
# 'disconnect' - to disconnect an NIC adapter,
#
# Output:
# ------
# It returns an object of VirtualDeviceConfigSpec for NIC adapter device.

sub create_network_spec {
   my ($vm_view, $network, $operation, $flagvalue) = @_;
   my $config_spec_operation;
   my $device;

   if($operation eq 'add') {
      if ($vm_view->runtime->powerState->val eq 'poweredOn') {
         Util::trace(0,"\nFor adding " . $network
                     . "' network, the virtual machine should be powered Off\n");
         return undef;
      }
      $config_spec_operation = VirtualDeviceConfigSpecOperation->new('add');
      my $backing_info
         = VirtualEthernetCardNetworkBackingInfo->new(deviceName => $network);
      $device = VirtualPCNet32->new(key => -1,
                                    backing => $backing_info);
      if($device) {
         Util::trace(0,"\nAdding NIC with the name '" . $network . "' . . .");
      }
   }

   if($operation eq 'setflag') {
      $config_spec_operation = VirtualDeviceConfigSpecOperation->new('edit');
      $device = VMUtils::find_device(vm => $vm_view,
                                     controller => $network);
      if($device) {
         if($flagvalue eq 'true') {
            if ($device->connectable->startConnected == 1) {
               Util::trace(0,"\nPowerOn flag for device '" . $device->deviceInfo->label
                   . "' is already set to TRUE\n");
               return undef;
            }
            if ($device->connectable->startConnected == 0) {
               Util::trace(0,"\nSetting PowerOn flag for device '"
                           . $device->deviceInfo->label . "' to TRUE\n");
               $device->connectable->startConnected(1);
            }
         }
         if($flagvalue eq 'false') {
            if ($device->connectable->startConnected == 0) {
               Util::trace(0,"\nPowerOn flag for device '" . $device->deviceInfo->label
                           . "' is already set to FALSE\n");
               return undef;
            }
            if ($device->connectable->startConnected == 1) {
               Util::trace(0,"\nSetting PowerOn flag for device '"
                           . $device->deviceInfo->label . "' to FALSE\n");
               $device->connectable->startConnected(0);
            }
         }
      }
   }

   if($operation eq 'remove') {
      if ($vm_view->runtime->powerState->val eq 'poweredOn') {
         Util::trace(0,"\nFor removing '" . $network
                     . "' network, the virtual machine should be powered Off\n");
         return undef;
      }
      $config_spec_operation = VirtualDeviceConfigSpecOperation->new('remove');
      $device = VMUtils::find_device(vm => $vm_view,
                                     controller => $network);
      if($device) {
         Util::trace(0,"\nRemoving NIC with the name '" . $network . "' . . .");
      }
   }

   if(($operation eq 'connect') || ($operation eq 'disconnect')) {
      $config_spec_operation = VirtualDeviceConfigSpecOperation->new('edit');
      $device = VMUtils::find_device(vm => $vm_view,
                                     controller => $network);

      if (($operation eq 'connect')
            && ($vm_view->runtime->powerState->val ne 'poweredOn')) {
         Util::trace(0,"\nFor connecting '" . $network
                     . "' network, the virtual machine should be powered On\n");
         return undef;
      }
      if (($operation eq 'disconnect')
            && ($vm_view->runtime->powerState->val ne 'poweredOn')) {
         Util::trace(0,"\nFor disconnecting '" . $network
                     . "' network, the virtual machine should be powered On\n");
         return undef;
      }
      if ($device) {
         if (($operation eq 'connect') && ($device->connectable->connected == 1)) {
            Util::trace(0,"\nDevice '" . $device->deviceInfo->label
                        . "' is already connected\n");
            return undef;
         }
         if (($operation eq 'disconnect') && ($device->connectable->connected == 0)) {
            Util::trace(0,"\nDevice '" . $device->deviceInfo->label
                        . "' is already disconnected\n");
            return undef;
         }

         if (($operation eq 'connect') && ($device->connectable->connected == 0)) {
            Util::trace(0,"\nConnecting device '" . $device->deviceInfo->label
                        . "' on Virtual Machine " . $vm_view->name . "\n");
            $device->connectable->connected(1);
         }
         if (($operation eq 'disconnect') && ($device->connectable->connected == 1)) {
            Util::trace(0,"\nDisconnecting device '" . $device->deviceInfo->label
                        . "' from Virtual Machine " . $vm_view->name . "\n");
            $device->connectable->connected(0);
         }
      }
   }
   
   if($device) {
      my $devspec = VirtualDeviceConfigSpec->new(operation => $config_spec_operation,
                                              device => $device);
      return $devspec;
   }
   
   return undef;
}


# This subroutine creates the configuration spec for a Floppy
# based on the operation.
# Input Parameters:
# ----------------
# vm_view    : Managed object of the virtual machine.
# name       : Floppy name.
# operation		: The Virtual Device Config Spec operation.
# flagvalue  : Value of the connectAtPowerOn flag. (true/false)
#              Required only for 'setflag' operation.
#
# The possible values for input parameter 'operation' can be
# 'add'        - to add a Floppy,
# 'remove'     - to remove a Floppy,
# 'setflag'    - to set the connectAtPowerOn flag for a Floppy,
# 'connect'    - to connect a Floppy,
# 'disconnect' - to disconnect a Floppy,
#
# Output:
# ------
# It returns an object of VirtualDeviceConfigSpec for Floppy.

sub create_floppy_spec {
   my ($vm_view, $name, $operation, $flagvalue) = @_;
   my ($config_spec_operation, $config_file_operation);
   my $floppy;
   if($operation eq 'setflag') {
      $config_spec_operation = VirtualDeviceConfigSpecOperation->new('edit');
      $floppy = VMUtils::find_device(vm => $vm_view,
                                     controller => $name);
      if($floppy && ($flagvalue eq 'true')) {
         if ($floppy->connectable->startConnected == 1) {
            Util::trace(0,"\nPowerOn flag for device '" . $floppy->deviceInfo->label
                        . "' is already set to TRUE\n");
            return undef;
         }
         if ($floppy->connectable->startConnected == 0) {
            Util::trace(0,"\nSetting PowerOn flag for device '"
                        . $floppy->deviceInfo->label . "' to TRUE\n");
            $floppy->connectable->startConnected(1);
         }
      }

      if($floppy && ($flagvalue eq 'false')) {
         if ($floppy->connectable->startConnected == 0) {
            Util::trace(0,"\nPowerOn flag for device '" . $floppy->deviceInfo->label
                        . "' is already set to FALSE\n");
            return undef;
         }
         if ($floppy->connectable->startConnected == 1) {
            Util::trace(0,"\nSetting PowerOn flag for device '"
                        . $floppy->deviceInfo->label . "' to FALSE\n");
            $floppy->connectable->startConnected(0);
         }
      }
   }

   if($operation eq 'add') {
      if ($vm_view->runtime->powerState->val eq 'poweredOn') {
         Util::trace(0,"\nFor adding '" . $name
                     . "' floppy, the virtual machine should be powered Off\n");
         return undef;
      }
      $config_spec_operation = VirtualDeviceConfigSpecOperation->new('add');
      my $controller = VMUtils::find_device(vm => $vm_view,
                                            controller => 'SCSI Controller 0');
      my $controllerKey = $controller->key;
      my $unitNumber = $#{$controller->device} + 2;
      my $floppy_backing_info
         = VirtualFloppyDeviceBackingInfo->new(deviceName => $name);
      $floppy = VirtualFloppy->new(controllerKey => $controllerKey,
                               unitNumber => $unitNumber,
                               key => -1,
                               backing => $floppy_backing_info);
      if($floppy) {
         Util::trace(0,"\nAdding floppy '" . $name . "' . . .");
      }
   }

   if($operation eq 'remove') {
      if ($vm_view->runtime->powerState->val eq 'poweredOn') {
         Util::trace(0,"\nFor removing '" . $name
                     . "' floppy, the virtual machine should be powered Off\n");
         return undef;
      }
      $config_spec_operation = VirtualDeviceConfigSpecOperation->new('remove');
      $floppy = VMUtils::find_device(vm => $vm_view,
                                     controller => $name);
      if($floppy) {
         Util::trace(0,"\nRemoving floppy '" . $name . "' . . .");
      }
   }

   if(($operation eq 'connect') || ($operation eq 'disconnect')) {
      $config_spec_operation = VirtualDeviceConfigSpecOperation->new('edit');
      $floppy = VMUtils::find_device(vm => $vm_view,
                                     controller => $name);
      if (($operation eq 'connect')
            && ($vm_view->runtime->powerState->val ne 'poweredOn')) {
         Util::trace(0,"\nFor connecting '" . $name
                     . "' network, the virtual machine should be powered On\n");
         return undef;
      }
      if (($operation eq 'disconnect')
            && ($vm_view->runtime->powerState->val ne 'poweredOn')) {
         Util::trace(0,"\nFor disconnecting '" . $name
                     . "' network, the virtual machine should be powered On\n");
         return undef;
      }
      if ($floppy) {
         if (($operation eq 'connect') && ($floppy->connectable->connected == 1)) {
            Util::trace(0,"\nDevice '" . $floppy->deviceInfo->label
                        . "' is already connected\n");
            return undef;
         }
         if (($operation eq 'disconnect') && ($floppy->connectable->connected == 0)) {
            Util::trace(0,"\nDevice '" . $floppy->deviceInfo->label
                        . "' is already disconnected\n");
            return undef;
         }
         if (($operation eq 'connect') && ($floppy->connectable->connected == 0)) {
            Util::trace(0,"\nConnecting device '" . $floppy->deviceInfo->label
                        . "' on Virtual Machine " . $vm_view->name . "\n");
            $floppy->connectable->connected(1);
         }
         if (($operation eq 'disconnect') && ($floppy->connectable->connected == 1)) {
            Util::trace(0,"\nDisconnecting device '" . $floppy->deviceInfo->label
                        . "' from Virtual Machine " . $vm_view->name . "\n");
            $floppy->connectable->connected(0);
         }
      }
   }
   
   if($floppy) {
      my $devspec = VirtualDeviceConfigSpec->new(operation => $config_spec_operation,
                                              device => $floppy);
      return $devspec;
   }
   return undef;
}




# This subroutine creates the configuration spec for a CD/DVD
# based on the operation.
# Input Parameters:
# ----------------
# vm_view    : Managed object of the virtual machine.
# name       : CD/DVD name.
# operation		: The Virtual Device Config Spec operation.
# flagvalue  : Value of the connectAtPowerOn flag. (true/false)
#              Required only for 'setflag' operation.
#
# The possible values for input parameter 'operation' can be
# 'add'        - to add a CD/DVD,
# 'remove'     - to remove a CD/DVD,
# 'setflag'    - to set the connectAtPowerOn flag for a CD/DVD,
# 'connect'    - to connect a CD/DVD,
# 'disconnect' - to disconnect a CD/DVD,
#
# Output:
# ------
# It returns an object of VirtualDeviceConfigSpec for CD/DVD.

sub create_cd_spec {
   my ($vm_view, $name, $operation, $flagvalue) = @_;
   my ($config_spec_operation, $config_file_operation);
   my $cd;

   if($operation eq 'setflag') {
      $config_spec_operation = VirtualDeviceConfigSpecOperation->new('edit');
      $cd = VMUtils::find_device(vm => $vm_view,
                                     controller => $name);

      if($cd) {
         if($flagvalue eq 'true') {
            if ($cd->connectable->startConnected == 1) {
               Util::trace(0,"\nPowerOn flag for device '"
                           . $cd->deviceInfo->label . "' is already set to TRUE\n");
               return undef;
            }
            if ($cd->connectable->startConnected == 0) {
               Util::trace(0,"\nSetting PowerOn flag for device '"
                           . $cd->deviceInfo->label . "' to TRUE\n");
               $cd->connectable->startConnected(1);
            }
         }

         if($flagvalue eq 'false') {
            if ($cd->connectable->startConnected == 0) {
               Util::trace(0,"\nPowerOn flag for device '"
                          . $cd->deviceInfo->label . "' is already set to FALSE\n");
               return undef;
            }
            if ($cd->connectable->startConnected == 1) {
               Util::trace(0,"\nSetting PowerOn flag for device '"
                           . $cd->deviceInfo->label . "' to FALSE\n");
               $cd->connectable->startConnected(0);
            }
         }
      }
   }

   if($operation eq 'add') {
      if ($vm_view->runtime->powerState->val eq 'poweredOn') {
         Util::trace(0,"\nFor adding '" . $name
                     . "' CD/DVD device, the virtual machine should be powered Off\n");
         return undef;
      }
      $config_spec_operation = VirtualDeviceConfigSpecOperation->new('add');
      my $controller = VMUtils::find_device(vm => $vm_view,
                                            controller => 'IDE 0');
      my $controllerKey = $controller->key;
      my $unitNumber = $#{$controller->device} + 1;
      

      my $cd_backing_info
         = VirtualCdromRemoteAtapiBackingInfo->new(deviceName => $name);

      my $description = Description->new(label => $name, summary => '111');
      
      $cd = VirtualCdrom->new(controllerKey => $controllerKey,
                              unitNumber => $unitNumber,
                              key => -1,
                              deviceInfo => $description,
                              backing => $cd_backing_info);

      if($cd) {
         Util::trace(0,"\nAdding cd '" . $name . "' . . .");
      }
   }

   if($operation eq 'remove') {
      if ($vm_view->runtime->powerState->val eq 'poweredOn') {
         Util::trace(0,"\nFor removing '" . $name
                     . "' CD/DVD device, the virtual machine should be powered Off\n");
         return undef;
      }
      $config_spec_operation = VirtualDeviceConfigSpecOperation->new('remove');
      $cd = VMUtils::find_device(vm => $vm_view,
                              controller => $name);
      if($cd) {
         Util::trace(0,"\nRemoving cd '" . $name . "' . . .");
      }
   }


   if(($operation eq 'connect') || ($operation eq 'disconnect')) {
      $config_spec_operation = VirtualDeviceConfigSpecOperation->new('edit');
      $cd = VMUtils::find_device(vm => $vm_view,
                                     controller => $name);

      if ($cd) {
         if (($operation eq 'connect')
               && ($vm_view->runtime->powerState->val ne 'poweredOn')) {
            Util::trace(0,"\nFor connecting '" . $name
                        . "' network, the virtual machine should be powered On\n");
            return undef;
         }
         if (($operation eq 'disconnect')
               && ($vm_view->runtime->powerState->val ne 'poweredOn')) {
            Util::trace(0,"\nFor disconnecting '" . $name
                        . "' network, the virtual machine should be powered On\n");
            return undef;
         }

         if (($operation eq 'connect') && ($cd->connectable->connected == 1)) {
            Util::trace(0,"\nDevice '" . $cd->deviceInfo->label
                        . "' is already connected\n");
            return undef;
         }
         if (($operation eq 'disconnect') && ($cd->connectable->connected == 0)) {
            Util::trace(0,"\nDevice '" . $cd->deviceInfo->label
                        . "' is already disconnected\n");
            return undef;
         }

         if (($operation eq 'connect') && ($cd->connectable->connected == 0)) {
            Util::trace(0,"\nConnecting device '" . $cd->deviceInfo->label
                        . "' on Virtual Machine " . $vm_view->name . "\n");
            $cd->connectable->connected(1);
         }
         if (($operation eq 'disconnect') && ($cd->connectable->connected == 1)) {
            Util::trace(0,"\nDisconnecting device '" . $cd->deviceInfo->label
                        . "' from Virtual Machine " . $vm_view->name . "\n");
            $cd->connectable->connected(0);
         }
      }
   }

   if($cd) {
      my $devspec = VirtualDeviceConfigSpec->new(operation => $config_spec_operation,
                                                 device => $cd);
      return $devspec;
   }
   
   return undef;
}



1;
