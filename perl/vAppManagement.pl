#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://communities.vmware.com/docs/DOC-9852

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
      help => "[query_vms|poweron|poweroff|shutdown|query_snaps|create_snap|commit_snap|commit_all_snap|goto_snap|link_clone|migrate]",
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
   cluster => {
      type => "=s",
      help => "Name of cluster to migrate vApp to",
      required => 0,
   }
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
my $cluster_name = Opts::get_option('cluster');

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
}elsif($operation eq 'migrate'){
		unless($cluster_name) {
			Util::disconnect();
			print color("red") . "Operation \"migrate\" requires command line param --cluster!\n\n" . color("reset");
			exit 1
		}
		&migrateVApp(
				srcvappname  => $vapp,
				dstvappname => $vapp_clone_name,
				dstclustername => $cluster_name,
				dstdatastorename => $vapp_datastore
		);
} else {
		print color("red") . "Invalid operation!\n" . color("reset");
}

Util::disconnect();

sub getvApp {
	my ($vappname, $properties) = @_;
	
	my $vapp_view;
	if ( $properties ){
		$vapp_view = Vim::find_entity_view(view_type => 'VirtualApp', filter => {"name" => $vappname}, properties => $properties);
	} else {
		$vapp_view = Vim::find_entity_view(view_type => 'VirtualApp', filter => {"name" => $vappname});
	}
	return $vapp_view;
}

sub getvAppVMs {
	my ($vappname) = @_;

	my $vapp_view = Vim::find_entity_view(view_type => 'VirtualApp',
                                          filter => {"name" => $vappname},
                                          properties => ["vAppConfig"]);
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

sub migrateVApp {
	my %args = @_;
	my $srcvappname = $args{srcvappname};
	my $dstvappname = $args{dstvappname};
	my $dstclustername = $args{dstclustername};
	my $dstdatastorename = $args{dstdatastorename};

	my $srcvappview = &getvApp($srcvappname, ['name', 'datastore', 'parentFolder', 'config', 'vm', 'vAppConfig' ]);
	unless($srcvappview) {
		Util::disconnect();
		print color("red") . "Unable to find vApp: \"$srcvappname\"!\n\n" . color("reset");
		exit 1;
	}

	my $dstclusterview = Vim::find_entity_view(view_type => 'ClusterComputeResource',
										filter => {"name" => $dstclustername},
										properties => ['resourcePool', 'host', 'datastore']);
	unless($dstclusterview) {
		Util::disconnect();
		print color("red") . "Unable to find Cluster '". $dstclustername."'!\n\n" . color("reset");
		exit 1;
	}
	my $dsthostview = undef;
	foreach my $hostref (@{$dstclusterview->{host}}){
		my $host = Vim::get_view( mo_ref => $hostref, properties => ['name', 'runtime'] );
		if ( $host->{runtime}->{connectionState}->{val} eq "connected" && $host->{runtime}->{inMaintenanceMode} == 0) {
			$dsthostview = $host;
			last
		}
	}
	unless($dsthostview){
		Util::disconnect();
		print color("red") . "Unable to find a suitable Host in Cluster '". $dstclustername."'!\n\n" . color("reset");
		exit 1;
	}

	my $dstdatastoreview = undef;
	my $sameds = undef;
	if ($srcvappview->{datastore}) {
		my $msg;
		print color("yellow")."Checking datastore availability on destination cluster '${dstclustername}' ... ".color("reset");
		if ($dstdatastorename) {
			$dstdatastoreview = Vim::find_entity_view( view_type => 'Datastore',
																	filter => { 'name' => $dstdatastorename},
																	properties => ['name']);

			foreach my $dsref ($dstclusterview->{datastore}){

			}

			$msg = color("red"). "Failed: Unable to find datastore destination '${dstdatastorename}' in cluster '${dstclustername}'!\n\n".color("reset");
		}else{
			$dstdatastoreview = Vim::get_view(mo_ref => $srcvappview->{datastore}[0],
														 properties => ['name']);
			$msg = color("red"). "Failed: Unable to find datastore of vApp '${srcvappname}'!\n\n".color("reset")
		}
		unless($dstdatastoreview){
			Util::disconnect();
			print $msg
			exit 1;
		}
		$dstdatastorename = $dstdatastoreview->name;
		print color("green")."ok\n".color("reset");
	}

	my $dstrpview = Vim::get_view(mo_ref => $dstclusterview->resourcePool);
	unless($dstrpview) {
		Util::disconnect();
		print color("red") . "Unable to find Cluster's '".$dstclustername."' Resource Pool!\n\n" . color("reset");
		exit 1;
	}

	my $folderview = Vim::get_view(mo_ref => $srcvappview->parentFolder);
	unless($folderview) {
		Util::disconnect();
		print color("red") . "Unable to find vApp's parent Folder!\n\n" . color("reset");
		exit 1;
	}

	my $resSpec = $srcvappview->config;
	my $ret;
	my $datestr =  &giveMeDate('MDYHMS');
	$dstvappname = $dstvappname||$srcvappname.'-clone-'.$datestr;
	eval {
		my $annotation = "Clone from vApp " . $srcvappname . " on " . $datestr;
		my $configSpec = VAppConfigSpec->new(annotation => $annotation);

		print color("yellow") . "Creating new vApp Container: '${dstvappname}' in cluster '${dstclustername}'...\n";
		$ret = $dstrpview->CreateVApp(name => $dstvappname, resSpec => $resSpec, configSpec => $configSpec, vmFolder => $folderview);
	};
	if($@) {
		print color("red") . "Failed: Error in creating vApp container! - " . $@ . "\n\n" . color("reset");
	} else {
		my $dstvappview = Vim::get_view(mo_ref => $ret);
		if($dstvappview) {
			print color("green") . "\tSuccessfully created new vApp container!\n\n" . color("reset");
		} else {
			print color("red") . "\tError in creating vApp container! - " . $@ . "\n\n" . color("reset");
		}
		my $vAppConfigSpec = getVAppConfigSpec( vappview => $srcvappview );
		my @movedvmsrefs = ();
		foreach my $vmref (@{$srcvappview->{vm}}){
			my $relocate_spec = VirtualMachineRelocateSpec->new (datastore => $dstdatastoreview->{mo_ref},
																				  host => $dsthostview->{mo_ref},
																				  pool => $dstrpview->{mo_ref});
			my $vmview = Vim::get_view(mo_ref => $vmref, properties=> ['name']);
			print color('yellow') . "Relocating virtual machine '".$vmview->{name}."' to host '".$dsthostview->{name}."' and datastore '$dstdatastorename'\n".color('reset');
			my $task = $vmview->RelocateVM(spec => $relocate_spec);
			push @movedvmsrefs, $vmref;
		}

		if (scalar @movedvmsrefs) {
			print color('yellow'). "Moving vms to new vApp.\n".color('reset');
			$dstvappview->MoveIntoResourcePool(list => [@movedvmsrefs]);
		}
		$dstvappview->ViewBase::update_view_data();
		&mapEntityConfigViaTag(configspec => $vAppConfigSpec, vappview => $dstvappview);
		&applyVAppConfig( vappview => $dstvappview, configspec=>$vAppConfigSpec);
		print color("magenta") . "New vApp '${dstvappname}' is ready! - Remember to remove source vApp '${srcvappname}'!\n\n" . color("reset");
	}
} # migrate VApp


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
		my $annotation = "Linked Clone from vApp " . $vappname . " on " . &giveMeDate('MDYHMS');
		my $configSpec = VAppConfigSpec->new(annotation => $annotation);

		print color("yellow") . "Creating new vApp Linked Clone Container: '" . $linkclonename . "' ...\n" . color("reset");
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
	my $vAppConfigSpec = getVAppConfigSpec( vappview => $vApp );
	my $lcvApp = &getvApp($linkclonename);	

	mapEntityConfigViaTag($vAppConfigSpec, $lcvApp->vAppConfig->entityConfig);
	print color("yellow") . "Updating new vApp container with meta data from " . $vappname . " ...\n" . color("reset");

	applyVAppConfig( vappview =>$lcvApp, configspec=>$vAppConfigSpec)
} # updatevAppContainer


sub applyVAppConfig{
	my %args = @_;
	my $vapp = $args{vappview};
	my $config = $args{configspec};
	my $vappname = $vapp->{name};
      eval {
         $vapp->UpdateVAppConfig(spec => $config);
         print color("green") . "\tSuccessfully updated meta data vApp Clonecontainer " . $vappname ."!\n\n" . color("reset");
      };
      if($@) {
         print color("red") . "Error in updating vApp container! - " . $@ . "\n\n" . color("reset");
      }
} # applyVAppConfig


sub mapEntityConfigViaTag {
	my %args = @_;
	my $vAppCfg = $args{configspec};
	my $dstVApp = $args{vappview};

	my $dstEntityCfg = $dstVApp->vAppConfig->entityConfig;
	my $resultEntityCfg = $vAppCfg->{entityConfig};
	foreach my $resultEntity ( sort {$a->tag cmp $b->tag} @$resultEntityCfg) {
		foreach my $dstEntity ( sort {$a->tag cmp $b->tag} @$dstEntityCfg) {
			if($resultEntity->tag eq $dstEntity->tag) {
				$resultEntity->{key} = $dstEntity->key;
			}
		}
	}
	return $vAppCfg;
} # mappEntityConfigViaTag


sub getVAppConfigSpec {
	my %args = @_;
	my $vApp = $args{vappview};
	my $vAppConfigSpec = VAppConfigSpec->new();

#	&& defined($lcvApp->vAppConfig->entityConfig)
	if(defined($vApp->vAppConfig->entityConfig)) {
                my $lc_entityConfigs = $vApp->vAppConfig->entityConfig;
#                my $newlc_entityConfigs = $lcvApp->vAppConfig->entityConfig;

                my @entityConfig = ();
                # tag = Name of Virtual Machine
                # key = moref of Virtual Machine eg. vm-208
                foreach my $lc ( @$lc_entityConfigs) {
                                        my $entitySpec = VAppEntityConfigInfo->new();

                                        $entitySpec->{'key'} = $lc->key;
                                        $entitySpec->{'tag'} = $lc->tag;

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
#                        }
#                }
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
	
	return $vAppConfigSpec;
} # getVAppConfigSpec

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
		my $entity = Vim::get_view(mo_ref => $_->key, properties => ['name']);
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
	my $licMgr = Vim::get_view(mo_ref => $service_content->licenseManager, properties => ['licenses']);

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
