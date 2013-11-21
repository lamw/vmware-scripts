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
# 12/18/2009
# http://engineering.ucsb.edu/~duonglt/vmware/
# http://communities.vmware.com/docs/DOC-9852

use strict;
use warnings;
use Term::ANSIColor;
use VMware::VILib;
use VMware::VIRuntime;

$SIG{__DIE__} = sub{Util::disconnect()};

my %opts = (
   vapp => {
      type => "=s",
      help => "Name of the vApp to perform the operation on",
      required => 1,
   },
   operation => {
      type => "=s",
      help => "[query_vms|poweron|poweroff|shutdown|query_snaps|create_snap|commit_snap|commit_all_snap|goto_snap|link_clone]",
      required => 1,
   },
   snapshotname => {
      type => "=s",
      help => "Name of the snapshot",
      required => 0,
   },
   vapp_clone_name => {
      type => "=s",
      help => "Name of the Cloned vApp",
      required => 0,
   },
   vapp_datastore => {
      type => "=s",
      help => "Name of the datastore to store new cloned vApp",
      required => 0,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();
my $hosttype = &validateConnection('4.0.0','licensed','VirtualCenter');

my (@vmlist,@newLinkedClones) = ();
my $vapp = Opts::get_option('vapp');
my $operation = Opts::get_option('operation');
my $snapshotname = Opts::get_option('snapshotname');
my $vapp_clone_name = Opts::get_option('vapp_clone_name');
my $vapp_datastore = Opts::get_option('vapp_datastore');

if($operation eq 'query_vms') {
	&queryVMs($vapp);
}elsif($operation eq 'link_clone') {
	unless($vapp_clone_name && $vapp_clone_name && $vapp_datastore && $snapshotname) {
		Util::disconnect();
                print color("red") . "Operation \"link_clone\" requires command line param --vapp_clone_name,--vapp_clone_name,--snapshotname and --vapp_datastore!\n\n" . color("reset");
                exit 1
	}
	&linkClonevApp($vapp,$vapp_clone_name,$vapp_datastore,$snapshotname);	
}elsif($operation eq 'query_snaps') {
	&queryvAppSnapshots($vapp);
}elsif($operation eq 'commit_snap') {
	unless($snapshotname) {
		Util::disconnect();
		print color("red") . "Operation \"commit\" requires command line param --snapshotname!\n\n" . color("reset");
		exit 1
	}
	&commitSnapshot($vapp,$snapshotname);
}elsif($operation eq 'commit_all_snap') {
	&commitAllSnapshots($vapp);
}elsif($operation eq 'create_snap') {
	unless($snapshotname) {
                Util::disconnect();
                print color("red") . "Operation \"create\" requires command line param --snapshotname!\n\n" . color("reset");
                exit 1
        }
        &createSnapshot($vapp,$snapshotname);
}elsif($operation eq 'goto_snap') {
	unless($snapshotname) {
                Util::disconnect();
                print color("red") . "Operation \"create\" requires command line param --snapshotname!\n\n" . color("reset");
                exit 1
        }
        &gotoSnapshot($vapp,$snapshotname);
}elsif($operation eq 'poweron') {
	&powerOnvApp($vapp);
}elsif($operation eq 'poweroff') {
        &powerOffvApp($vapp);
}elsif($operation eq 'shutdown') {
        &shutdownvApp($vapp);
} else {
	print color("red") . "Invalid operation!\n" . color("reset");
}

Util::disconnect();

sub getvApp {
	my ($vappname) = @_;

	my $vapp_view = Vim::find_entity_view(view_type => 'VirtualApp', filter => {"name" => $vappname});
	
	return $vapp_view;
}

sub getvAppVMs {
	my ($vappname) = @_;

	my $vapp_view = &getvApp($vappname);
        unless($vapp_view) {
                Util::disconnect();
                print color("red") . "Unable to find vApp: \"$vappname\"!\n\n" . color("reset");
                exit 1;
        }
        unless($vapp_view->vAppConfig->entityConfig) {
                Util::disconnect();
                print color("red") . "Unable to find any VirtualMachines in the vApp!\n\n" . color("reset");
                exit 1;
        }

        my $vapp_entities = $vapp_view->vAppConfig->entityConfig;

	return $vapp_entities;
}

sub linkClonevApp {
	my ($vappname,$linkclonename,$ds,$snapshotname) = @_;

	my $vApp = &getvApp($vappname);
	unless($vApp) {
		Util::disconnect();
                print color("red") . "Unable to find vApp: \"$vappname\"!\n\n" . color("reset");
                exit 1;
	}

	if($vApp->summary->vAppState->val ne "stopped") {
		Util::disconnect();
		print color("red") . "vApp: \"$vappname\" must be powered off!\n\n" . color("reset");
		exit 1;
	}

	my $vAppRP = Vim::get_view(mo_ref => $vApp->parent);
	unless($vAppRP) {
		Util::disconnect();
                print color("red") . "Unable to find vApp's parent Resource Pool!\n\n" . color("reset");
                exit 1;
	}

	my $vAppFolder = Vim::get_view(mo_ref => $vApp->parentFolder);
	unless($vAppFolder) {
		Util::disconnect();
                print color("red") . "Unable to find vApp's parent Folder!\n\n" . color("reset");
                exit 1;
	}

	my $resSpec = $vApp->config;
	my $ret;

	eval {
		my $annotation = "Linked Clone from vApp " . $ vappname . " on " . &giveMeDate('MDYHMS');
		my $configSpec = VAppConfigSpec->new(annotation => $annotation);

		print color("yellow") . "Creating new vApp Linked Clone Container: " . $linkclonename . " ...\n" . color("reset");
		$ret = $vAppRP->CreateVApp(name => $linkclonename, resSpec => $resSpec, configSpec => $configSpec, vmFolder => $vAppFolder);
	};
	if($@) {
                print color("red") . "Error in creating vApp container! - " . $@ . "\n\n" . color("reset");
        } else {
		my $lcvApp = Vim::get_view(mo_ref => $ret);

		if($lcvApp) {
			print color("green") . "\tSuccessfully created new vApp Linked Clone container!\n\n" . color("reset");
		} else {
			print color("red") . "\tError in creating vApp container! - " . $@ . "\n\n" . color("reset");
		}
		&createvAppLinkedClone($vappname,$vAppRP,$vAppFolder,$ds,$snapshotname);
		&moveLinkedClonesIntovApp($linkclonename);
		&updatevAppContainer($vappname,$linkclonename);
		print color("magenta") . "New vApp Linked Clone \"" . $linkclonename . "\" is ready! - Remember not to delete/commit snapshot \"" . $snapshotname . "\"!\n\n" . color("reset");
	}
}

sub createvAppLinkedClone {
	my ($vappname,$rp,$folder,$ds,$snap) = @_;

	my $vApp = &getvApp($vappname);

	my $vms = Vim::get_views(mo_ref_array => $vApp->vm);

	foreach my $vm (@$vms) {
		my $host = Vim::get_view(mo_ref => $vm->runtime->host);
		my $ds_view = &findDatastore($host,$ds);
		&createLinkClone($vm,$host,$ds_view,$snap,$folder);
	}	
}

sub createLinkClone {
	my ($vm,$host,$ds,$snap,$folder) = @_;

	my $append = &giveMeDate('MDYHMS');
	#my $newclonename = $vm->name . "-" . $append;
	my $newclonename = $vm->name;

	my $comp_res_view = Vim::get_view(mo_ref => $host->parent);

	my ($vm_snapshot,$ref,$nRefs);
	if(defined $vm->snapshot) {
		($ref, $nRefs) = &findSnapshot($vm->snapshot->rootSnapshotList,$snap);
      	}
      	if (defined $ref && $nRefs == 1) {
        	$vm_snapshot = Vim::get_view(mo_ref => $ref->snapshot);
	}

	unless($vm_snapshot) {
                print color("red") . "\tError snapshot \"$snap\" does not exists for " . $vm->name . "!\n\n" . color("reset");
		Util::disconnect();
		exit 1;
        }

	my $relocate_spec = VirtualMachineRelocateSpec->new(datastore => $ds,
        		host => $host,
			diskMoveType => "createNewChildDiskBacking",
			pool => $comp_res_view->resourcePool
	);

	my $clone_spec = VirtualMachineCloneSpec->new(
        	powerOn => 0,
                template => 0,
		snapshot => $vm_snapshot,
		location => $relocate_spec,
	);

	print color("yellow") . "Creating new Linked Clone: " . $newclonename . " ...\n" . color("reset");

	eval {
		my $task = $vm->CloneVM_Task(folder => $folder,
                	name => $newclonename,
                        spec => $clone_spec
		);
		my $message = color("green") . "\tSuccessfully created new Linked Clone!" . color("reset");
		my $return = &getStatus($task,$message);
		my $vmRef = Vim::get_view(mo_ref => $return);
		push @newLinkedClones, $vmRef;	
        };
	if($@) {
		print color("red") . "Error in creating Linked Clone! - " . $@ . "\n\n" . color("reset");
		Util::disconnect();
		exit 1;
	}
}

sub moveLinkedClonesIntovApp {
	my ($newvApp) = @_;

	my $vApp = &getvApp($newvApp);

	print color("yellow") . "\nMoving new Linked Clone VMs into vApp " . $newvApp . " ...\n" . color("reset");
	eval {
		$vApp->MoveIntoResourcePool(list => [@newLinkedClones]);
		print color("green") . "\tSuccessfully moved new Linked Clone VMs into vApp!\n\n" . color("reset");
	};
	if($@) {
		print color("red") . "Error in moving Linked Clone VMs into vApp! - " . $@ . "\n\n" . color("reset");
	}
}

sub updatevAppContainer {
	my ($vappname,$linkclonename) = @_;

	my $vApp = &getvApp($vappname);
	my $lcvApp = &getvApp($linkclonename);

	my $vAppConfigSpec = VAppConfigSpec->new();

	if(defined($vApp->vAppConfig->entityConfig) && defined($lcvApp->vAppConfig->entityConfig)) {
                my $lc_entityConfigs = $vApp->vAppConfig->entityConfig;
                my $newlc_entityConfigs = $lcvApp->vAppConfig->entityConfig;

                my @entityConfig = ();
                foreach my $lc ( sort {$a->tag cmp $b->tag} @$lc_entityConfigs) {
                        foreach my $newlc ( sort {$a->tag cmp $b->tag} @$newlc_entityConfigs) {
                                if($lc->tag eq $newlc->tag) {
                                        my $entitySpec = VAppEntityConfigInfo->new();

                                        $entitySpec->{'key'} = $newlc->key;

                                        if(defined($lc->startAction)) {
                                                $entitySpec->{'startAction'} = $lc->startAction;
                                        }
                                        if(defined($lc->startDelay)) {
                                                $entitySpec->{'startDelay'} = $lc->startDelay;
                                        }
                                        if(defined($lc->startOrder)) {
                                                $entitySpec->{'startOrder'} = $lc->startOrder;
                                        }

                                        if(defined($lc->stopAction)) {
                                                $entitySpec->{'stopAction'} = $lc->stopAction;
                                        }
                                        if(defined($lc->stopDelay)) {
                                                $entitySpec->{'stopDelay'} = $lc->stopDelay;
                                        }
                                        if(defined($lc->waitingForGuest)) {
                                                $entitySpec->{'waitingForGuest'} = $lc->waitingForGuest;
                                        }
                                        push @entityConfig,$entitySpec;
                                }
                        }
                }
                $vAppConfigSpec->{'entityConfig'} = \@entityConfig;
        }

        if(defined($vApp->vAppConfig->eula)) {
                $vAppConfigSpec->{'eula'} = $vApp->vAppConfig->eula;
        }

        if(defined($vApp->vAppConfig->installBootRequired)) {
                $vAppConfigSpec->{'installBootRequired'} = $vApp->vAppConfig->installBootRequired;
        }

        if(defined($vApp->vAppConfig->installBootStopDelay)) {
                $vAppConfigSpec->{'installBootStopDelay'} = $vApp->vAppConfig->installBootStopDelay;
        }

        if(defined($vApp->vAppConfig->ipAssignment)) {
                $vAppConfigSpec->{'ipAssignment'} = $vApp->vAppConfig->ipAssignment;
        }

        if(defined($vApp->vAppConfig->ovfEnvironmentTransport)) {
                $vAppConfigSpec->{'ovfEnvironmentTransport'} = $vApp->vAppConfig->ovfEnvironmentTransport
        }

        if(defined($vApp->vAppConfig->ovfEnvironmentTransport)) {
                $vAppConfigSpec->{'ovfEnvironmentTransport'} = $vApp->vAppConfig->ovfEnvironmentTransport;
        }

        if(defined($vApp->vAppConfig->ovfSection)) {
                $vAppConfigSpec->{'ovfSection'} = $vApp->vAppConfig->ovfSection;
        }

	if(defined($vApp->vAppConfig->product)) {
                my $products = $vApp->vAppConfig->product;

		my @productConfig = ();
                foreach(@$products) {
                        my $info = VAppProductInfo->new();
                        if(defined($_->appUrl)) {
                                $info->{'appUrl'} = $_->appUrl;
                        }
                        if(defined($_->classId)) {
                                $info->{'classId'} = $_->classId;
                        }
                        if(defined($_->fullVersion)) {
                                $info->{'fullVersion'} = $_->fullVersion;
                        }
                        if(defined($_->instanceId)) {
                                $info->{'instanceId'} = $_->instanceId;
                        }
                        if(defined($_->name)) {
                                $info->{'name'} = $_->name;
                        }
                        if(defined($_->productUrl)) {
                                $info->{'productUrl'} = $_->productUrl;
                        }
                        if(defined($_->vendor)) {
                                $info->{'vendor'} = $_->vendor;
                        }
                        if(defined($_->vendorUrl)) {
                                $info->{'vendorUrl'} = $_->vendorUrl;
                        }
                        if(defined($_->version)) {
                                $info->{'version'} = $_->version;
                        }
                        $info->{'key'} = $_->key;

                        my $operation = ArrayUpdateOperation->new('edit');
                        my $productSpec = VAppProductSpec->new(info => $info, operation => $operation);
			push @productConfig, $productSpec;
                }
		$vAppConfigSpec->{'product'} = \@productConfig;
        }

	if(defined($vApp->vAppConfig->property)) {
                my $propertys = $vApp->vAppConfig->property;

		my @propertyConfig = ();
                foreach(@$propertys) {
                        my $info = VAppPropertyInfo->new();

                        if(defined($_->category)) {
                                $info ->{'category'} = $_->category;
                        }
                        if(defined($_->classId)) {
                                $info->{'classId'} = $_->classId;
                        }
                        if(defined($_->defaultValue)) {
                                $info->{'defaultValue'} = $_->defaultValue;
                        }
                        if(defined($_->description)) {
                                $info->{'description'} = $_->description;
                        }
                        if(defined($_->id)) {
                                $info->{'id'} = $_->id;
                        }
                        if(defined($_->instanceId)) {
                                $info->{'instanceId'} = $_->instanceId;
                        }
                        if(defined($_->label)) {
                                $info->{'label'} = $_->label;
                        }
                        if(defined($_->type)) {
                                $info->{'type'} = $_->type;
                        }
                        if(defined($_->userConfigurable)) {
                                $info->{'userConfigurable'} = $_->userConfigurable;

                        }
                        if(defined($_->value)) {
                                $info->{'value'} = $_->value;
                        }
                        $info->{'key'} = $_->key;

                        my $operation = ArrayUpdateOperation->new('add');
                        my $propertySpec = VAppPropertySpec->new(info => $info, operation => $operation);
			push @propertyConfig, $propertySpec;
                }
		$vAppConfigSpec->{'property'} = \@propertyConfig;
	}
	
	print color("yellow") . "Updating new vApp Linked Clone container with meta data from " . $vappname . " ...\n" . color("reset");
        eval {
                $lcvApp->UpdateVAppConfig(spec => $vAppConfigSpec);
                print color("green") . "\tSuccessfully updated meta data vApp Linked Clonecontainer " . $linkclonename ."!\n\n" . color("reset");
        };
        if($@) {
                print color("red") . "Error in updating vApp container! - " . $@ . "\n\n" . color("reset");
        }
}

sub powerOnvApp {
	my ($vappname) = @_;

	my $vapp_view = Vim::find_entity_view(view_type => 'VirtualApp', filter => {"name" => $vappname});
        unless($vapp_view) {
                Util::disconnect();
                print color("red") . "Unable to find vApp: \"$vappname\"!\n\n" . color("reset");
                exit 1;
        }
	print color("cyan") . "Powering on vApp: $vappname\n" . color("reset");
        my $task = $vapp_view->PowerOnVApp_Task();
        my $msg = color("green") . "\tSucessfully powered on vApp!\n" . color("reset");
        &getStatus($task,$msg);	
}

sub powerOffvApp {
        my ($vappname) = @_;

        my $vapp_view = Vim::find_entity_view(view_type => 'VirtualApp', filter => {"name" => $vappname});
        unless($vapp_view) {
                Util::disconnect();
                print color("red") . "Unable to find vApp: \"$vappname\"!\n\n" . color("reset");
                exit 1;
        }
        print color("cyan") . "Powering off vApp: $vappname\n" . color("reset");
        my $task = $vapp_view->PowerOffVApp_Task(force => 'true');
        my $msg = color("green") . "\tSucessfully powered off vApp!\n" . color("reset");
        &getStatus($task,$msg);
}

sub shutdownvApp {
        my ($vappname) = @_;

        my $vapp_view = Vim::find_entity_view(view_type => 'VirtualApp', filter => {"name" => $vappname});
        unless($vapp_view) {
                Util::disconnect();
                print color("red") . "Unable to find vApp: \"$vappname\"!\n\n" . color("reset");
                exit 1;
        }
        print color("cyan") . "Shutting down vApp: $vappname\n" . color("reset");
        my $task = $vapp_view->PowerOffVApp_Task(force => 'false');
        my $msg = color("green") . "\tSucessfully shutdown on vApp!\n" . color("reset");
        &getStatus($task,$msg);
}

sub queryvAppSnapshots {
	my ($vappname) = @_;

	my $vapp_entities = &getvAppVMs($vappname);

	print color("cyan") . "vApp: $vappname\n" . color("reset");

	foreach(@$vapp_entities) {
                my $entity = Vim::get_view(mo_ref => $_->key);
                if($entity->isa('VirtualMachine')) {
        		if($entity->snapshot) {
        			print_tree($entity->name,$entity->snapshot->currentSnapshot,$entity->snapshot->rootSnapshotList);
        		}
		}
	}
}

sub gotoSnapshot {
	my ($vappname,$snapname) = @_;

        my $vapp_entities = &getvAppVMs($vappname);

        print color("cyan") . "Reverting snapshot for vApp: $vappname\n" . color("reset");
        foreach(@$vapp_entities) {
                my $entity = Vim::get_view(mo_ref => $_->key);
                if($entity->isa('VirtualMachine')) {
			if($entity->snapshot) {
	                        my ($node,$cnt) = findSnapshot($entity->snapshot->rootSnapshotList,$snapname);
				if($node && $cnt == 1) {
					my $snapshot = Vim::get_view(mo_ref => $node->snapshot);
	
	                	        print color("yellow") . "Reverting to snapshot \"$snapname\" for \"" . $entity->name . "\" ...\n" . color("reset");
        	                	my $task = $snapshot->RevertToSnapshot_Task();
	        	                my $msg = color("green") . "\tSucessfully reverted to snapshot for \"" . $entity->name . "\"!\n" . color("reset");
        	        	        &getStatus($task,$msg);
				} else {
					print color("red") . "Unable to locate snapshot \"$snapname\" from " . $entity->name . "!\n\n" . color("reset");
				}
                	} else {
				print color("red") . "No snapshot named \"$snapname\" found for VM \"" . $entity->name . "\"!\n\n" . color("reset");
			}
		}
        }
}

sub createSnapshot {
	my ($vappname,$snapname) = @_;

        my $vapp_entities = &getvAppVMs($vappname);

	print color("cyan") . "Creating snapshot for vApp: $vappname\n" . color("reset");
        foreach(@$vapp_entities) {
                my $entity = Vim::get_view(mo_ref => $_->key);
                if($entity->isa('VirtualMachine')) {
			print color("yellow") . "Creating snapshot \"$snapname\" for \"" . $entity->name . "\" ...\n" . color("reset");
			my $task = $entity->CreateSnapshot_Task(name => $snapname, description => $snapname . " for vApp $vappname", memory => 'false', quiesce => 'true');
			my $msg = color("green") . "\tSucessfully created snapshot for \"" . $entity->name . "\"!\n" . color("reset");
                        &getStatus($task,$msg);
		}
	}
}

sub commitSnapshot {
	my ($vappname,$snapname) = @_;

	my $vapp_entities = &getvAppVMs($vappname);

	print color("cyan") . "Committing snapshot for vApp: $vappname\n" . color("reset");
	foreach(@$vapp_entities) {
                my $entity = Vim::get_view(mo_ref => $_->key);
                if($entity->isa('VirtualMachine')) {
                        if($entity->snapshot) {
				my ($node,$cnt) = findSnapshot($entity->snapshot->rootSnapshotList,$snapname);
                                if($node && $cnt == 1) {		
					my $snapshot = Vim::get_view(mo_ref => $node->snapshot);
		
					print color("yellow") . "Committing snapshot \"$snapname\" for \"" . $entity->name . "\" ...\n" . color("reset");
					my $task = $snapshot->RemoveSnapshot_Task(removeChildren => 'false');
        	                        my $msg = color("green") . "\tSucessfully committed snapshot for \"" . $entity->name . "\"!\n" . color("reset");
                	                &getStatus($task,$msg);	
				} else {
					print color("red") . "Unable to locate snapshot \"$snapname\" from " . $entity->name . "!\n\n" . color("reset");
				}
			} else {
				print color("red") . "No snapshot named \"$snapname\" found for VM \"" . $entity->name . "\"!\n\n" . color("reset");
			}
		}
	}	
}

sub commitAllSnapshots {
	my ($vappname) = @_;

	my $vapp_entities = &getvAppVMs($vappname);

	print color("cyan") . "Committing ALL snapshots for vApp: $vappname\n" . color("reset");
	foreach(@$vapp_entities) {
		my $entity = Vim::get_view(mo_ref => $_->key);
		if($entity->isa('VirtualMachine')) {
			if($entity->snapshot) {	
				print color("yellow") . "Committing ALL snapshots for \"" . $entity->name . "\" ...\n" . color("reset");
				my $task = $entity->RemoveAllSnapshots_Task();
				my $msg = color("green") . "\tSucessfully committed ALL snapshots for \"" . $entity->name . "\"!\n" . color("reset");
				&getStatus($task,$msg);
			} else {
				print color("red") . "No snapshots found for  VM \"" . $entity->name . "\"!\n\n" . color("reset");
			}
		}
	}
}	

sub queryVMs {
	my ($vappname) = @_;

	my $vapp_entities = &getvAppVMs($vappname);

	print color("cyan") . "vApp: $vappname\n" . color("reset");
	foreach(@$vapp_entities) {
		my $entity = Vim::get_view(mo_ref => $_->key);
		if($entity->isa('VirtualMachine')) {
			print "\tVM: " . color("yellow") . $entity->name . "\n" . color("reset");
		} else {
			print "\tvApp: " . color("yellow") . $entity->name . "\n" . color("reset");
		}
	}
}

sub print_tree {
        my ($vm, $ref, $tree) = @_;
        my $head = "";
	
	my ($vmname,$snapshotname,$description);

format output =
@<<<<<<<<<<<<<<<<<<<<<<<<<@<<<<<<<<<<<<<<<<<<<@<<<<<<<<<<<<<<<<<<<<<<<<
$vmname,        $snapshotname,  $description
-------------------------------------------------------------------------------
.

$~ = 'output';

        foreach my $node (@$tree) {
                $head = ($ref->value eq $node->snapshot->value) ? " " : " " if (defined $ref);
                my $desc = $node->description;
                if($desc eq "" ) { $desc = "NO DESCRIPTION"; }
		$vmname = $vm;
		$snapshotname = $node->name;
		$description = $desc;
		write;
                print_tree($vm, $ref, $node->childSnapshotList);
        }
}

sub findSnapshot {
	my ($tree, $snapname) = @_;
	my $ref = undef;
	my $count = 0;

	foreach my $node (@$tree) {
		if($node->name eq $snapname) {
			$ref = $node;
			$count++;
		} 
		my ($subRef, $subCount) = findSnapshot($node->childSnapshotList, $snapname);
		$count = $count + $subCount;
      		$ref = $subRef if ($subCount);
	}
	return ($ref,$count);
}

sub findDatastore {
	my ($host,$dsname) = @_;
	my $ret;

	my $datastores = Vim::get_views(mo_ref_array => $host->datastore);
	foreach(@$datastores) {
		if($_->name eq $dsname) {
			$ret = $_;	
		}	
	}
	return $ret;
}


sub validateConnection {
	my ($host_version,$host_license,$host_type) = @_;
	my $service_content = Vim::get_service_content();
	my $licMgr = Vim::get_view(mo_ref => $service_content->licenseManager);	

	########################
	# CHECK HOST VERSION
	########################
	if(!$service_content->about->version ge $host_version) {
		Util::disconnect();
		print color("red") . "This script requires your ESX(i) host to be greater than $host_version\n\n" . color("reset");
		exit 1;
	}

	########################
	# CHECK HOST LICENSE
	########################
	my $licenses = $licMgr->licenses;
	foreach(@$licenses) {
		if($_->editionKey eq 'esxBasic' && $host_license eq 'licensed') {
			Util::disconnect();
	                print color("red") . "This script requires your ESX(i) be licensed, the free version will not allow you to perform any write operations!\n\n" . color("reset");
			exit 1;
		}
	}

	########################
	# CHECK HOST TYPE
	########################
	if($service_content->about->apiType ne $host_type && $host_type ne 'both') {
		Util::disconnect();
                print color("red") . "This script needs to be executed against $host_type\n\n" . color("reset");
		exit 1
	}

	return $service_content->about->apiType;
}

sub getStatus {
        my ($taskRef,$message) = @_;

        my $task_view = Vim::get_view(mo_ref => $taskRef);
        my $taskinfo = $task_view->info->state->val;
        my $continue = 1;
        while ($continue) {
                my $info = $task_view->info;
                if ($info->state->val eq 'success') {
			print $message . "\n";
                        return $info->result;
                        $continue = 0;
                } elsif ($info->state->val eq 'error') {
                        my $soap_fault = SoapFault->new;
                        $soap_fault->name($info->error->fault);
                        $soap_fault->detail($info->error->fault);
                        $soap_fault->fault_string($info->error->localizedMessage);
                        die "$soap_fault\n";
                }
                sleep 5;
                $task_view->ViewBase::update_view_data();
        }
}

sub giveMeDate {
        my ($date_format) = @_;
        my %dttime = ();
        my $my_time;
        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);

        ### begin_: initialize DateTime number formats
        $dttime{year }  = sprintf "%04d",($year + 1900);  ## four digits to specify the year
        $dttime{mon  }  = sprintf "%02d",($mon + 1);      ## zeropad months
        $dttime{mday }  = sprintf "%02d",$mday;           ## zeropad day of the month
        $dttime{wday }  = sprintf "%02d",$wday + 1;       ## zeropad day of week; sunday = 1;
        $dttime{yday }  = sprintf "%02d",$yday;           ## zeropad nth day of the year
        $dttime{hour }  = sprintf "%02d",$hour;           ## zeropad hour
        $dttime{min  }  = sprintf "%02d",$min;            ## zeropad minutes
        $dttime{sec  }  = sprintf "%02d",$sec;            ## zeropad seconds
        $dttime{isdst}  = $isdst;

        if($date_format eq 'MDYHMS') {
                $my_time = "$dttime{year}$dttime{mon}$dttime{mday}_$dttime{hour}$dttime{min}$dttime{sec}";
        }
        elsif ($date_format eq 'MDY') {
                $my_time = "$dttime{mon}/$dttime{mday}/$dttime{year}";
        }
        return $my_time;
}
