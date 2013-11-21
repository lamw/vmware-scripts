#!/usr/bin/perl -w
# Copyright (c) 2009-2011 William Lam All rights reserved.

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
use Term::ANSIColor;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
        operation => {
                type => "=s",
                help => "Operation to perform [list|query|create|delete|add_datastore|remove_datastore|ent_maint|exi_maint]",
                required => 1,
        },
	pod => {
		type => "=s",
                help => "Name of the datastore cluster pod",
		required => 0,
	},
	datacenter => {
                type => "=s",
                help => "Name of the datacenter to create datastore cluster pod under",
		required => 0,
        },
	datastore => {
                type => "=s",
                help => "Name of VMware datastore",
		required => 0,
        },
	datastore_file => {
                type => "=s",
                help => "File containing list of VMware datastores",
	        required => 0,
        },
	enable_sdrs => {
                type => "=s",
                help => "Enable Storage DRS on datastore cluster pod [true|false]",
	        required => 0,
        },
	sdrs_automation => {
                type => "=s",
                help => "Storage DRS Automation level [manual|automated]",
	        required => 0,
        },
	enable_sdrs_iometric => {
                type => "=s",
                help => "Enable Storage DRS I/O Metric for SDRS recommendations [true|false]",
	        required => 0,
        },
	sdrs_util_space => {
                type => "=s",
                help => "Utilization space threshold [50-100]",
		required => 0,
        },
	sdrs_latency => {
                type => "=s",
                help => "I/O Latency [5-50]",
                required => 0,
        },
	sdrs_util_diff => {
                type => "=s",
                help => "No SDRS recommendations until difference between source and destination [1-50]",
                required => 0,
        },
	sdrs_evaluate_period => {
                type => "=s",
                help => "Evaluate I/O Load every 60 minutes (e.g. 8hrs = 480)",
	        required => 0,
        },
	sdrs_imbal_thres => {
                type => "=s",
                help => "I/O imbalance threshold [1-100]",
	        required => 0,
        },
);

# validate options, and connect to the server
Opts::add_options(%opts);

Opts::parse();
Opts::validate();
Util::connect();

my $operation = Opts::get_option('operation');
my $pod = Opts::get_option('pod');
my $datacenter = Opts::get_option('datacenter');
my $datastore = Opts::get_option('datastore');
my $datastore_file = Opts::get_option('datastore_file');
my $enable_sdrs = Opts::get_option('enable_sdrs');
my $sdrs_automation = Opts::get_option('sdrs_automation');
my $enable_sdrs_iometric = Opts::get_option('enable_sdrs_iometric');
my $sdrs_util_space = Opts::get_option('sdrs_util_space');
my $sdrs_latency = Opts::get_option('sdrs_latency');
my $sdrs_util_diff= Opts::get_option('sdrs_util_diff');
my $sdrs_evaluate_period = Opts::get_option('sdrs_evaluate_period');
my $sdrs_imbal_thres = Opts::get_option('sdrs_imbal_thres');
my (@pods,@datastores) = ();
my $productSupport = "vpx";
my @supportedVersion = qw(5.0.0);

&validateSystem(Vim::get_service_content()->about->version,Vim::get_service_content()->about->productLineId);

if($operation eq "list") {
	my $pods = &findStoragePod(undef);
	foreach(sort{$a->name cmp $b->name}@$pods) {
		&print($_->name . "\n","cyan");
        }
} elsif($operation eq "query") {
	unless($pod) {
		Util::disconnect();
		&print("Operation \"query\" requires \"pod\" variable to be defined\n\n","yellow");
		exit 1;
	}
	my $pod_view = &findStoragePod($pod);
	if($pod_view) {
		if($pod_view->childEntity) {
			&getStoragePodConfig($pod_view);
		} else {
			&print("Datastore cluster does not contain any datastores\n\n","yellow");
		}
	} else {
		&print("Unable to locate Datastore Cluster: \"$pod\"\n\n","red");
	}
} elsif($operation eq "create") {
	unless($pod && $datacenter && ($datastore_file || $datastore)) {
                Util::disconnect();
                &print("Operation \"create\" requires \"pod\",\"datacenter\" and \"datastore\" or \"datastore_file\" variables to be defined\n\n","yellow");
                exit 1;
        }
	my ($podView);
	my $dcFolder = &getDatacenterFolder($datacenter);

	# create storage pod
	$podView = &createStoragePod($pod,$dcFolder);

	# add datastores to pod
	&addAndRemoveDatastoreToPod($podView,"add");

	# configure storage pod settings
	&configureStoragePod($podView);
} elsif($operation eq "delete") {
	 unless($pod) {
                Util::disconnect();
                &print("Operation \"delete\" requires \"pod\" variable to be defined\n\n","yellow");
                exit 1;
        }
	my $pod_view = &findStoragePod($pod);
        if($pod_view) {
       		my $verify = &promptUser("Would you like to delete datastore cluster (datastores will stay intact): \"$pod\" now? [yes|no]");
		if($verify =~ m/yes/) {
			&deleteStoragePod($pod_view);
		} else {
			print "Deletion aborted!\n\n";
		}
	} else {
                &print("Unable to locate Datastore Cluster: \"$pod\"\n\n","red");
        }
} elsif($operation eq "add_datastore") {
	unless($pod && ($datastore_file || $datastore)) {
                Util::disconnect();
                &print("Operation \"add_datastore\" requires \"pod\" and \"datastore\" or \"datastore_file\" variables to be defined\n\n","yellow");
                exit 1;
        }
	my $pod_view = &findStoragePod($pod);
	if($pod_view) {
		print "Adding datastore(s) to datastore cluster: \"$pod\" ...\n";
		&addAndRemoveDatastoreToPod($pod_view,"add");
		$pod_view->ViewBase::update_view_data();
		&getStoragePodConfig($pod_view);
	} else {
                &print("Unable to locate Datastore Cluster: \"$pod\"\n\n","red");
        }
} elsif($operation eq "remove_datastore") {
	unless($pod && ($datastore_file || $datastore)) {
                Util::disconnect();
                &print("Operation \"remove_datastore\" requires \"pod\" and \"datastore\" or \"datastore_file\" variables to be defined\n\n","yellow");
                exit 1;
        }
        my $pod_view = &findStoragePod($pod);
        if($pod_view) {
                print "Removing datastore(s) from datastore cluster: \"$pod\" ...\n";
                &addAndRemoveDatastoreToPod($pod_view,"remove");
                $pod_view->ViewBase::update_view_data();
                &getStoragePodConfig($pod_view);
        } else {
                &print("Unable to locate Datastore Cluster: \"$pod\"\n\n","red");
        }
} elsif($operation eq "ent_maint") {
	unless($pod && $datastore) {
                Util::disconnect();
                &print("Operation \"ent_maint\" requires \"pod\" and \"datastore\" variables to be defined\n\n","yellow");
                exit 1;
        }
        my $pod_view = &findStoragePod($pod);
        if($pod_view) {
		print "Putting datastore: \"$datastore\" into maintenance mode in datastore cluster: \"$pod\" ...\n";
		&maintenanceModeStoragePod($pod_view,$datastore,"enter");
	} else {
                &print("Unable to locate Datastore Cluster: \"$pod\"\n\n","red");
        }
} elsif($operation eq "exi_maint") {
        unless($pod && $datastore) {
                Util::disconnect();
                &print("Operation \"exi_maint\" requires \"pod\" and \"datastore\" variables to be defined\n\n","yellow");
                exit 1;
        }
        my $pod_view = &findStoragePod($pod);
        if($pod_view) {
                print "Taking datastore: \"$datastore\" out of maintenance mode in datastore cluster: \"$pod\" ...\n";
                &maintenanceModeStoragePod($pod_view,$datastore,"exit");
        } else {
                &print("Unable to locate Datastore Cluster: \"$pod\"\n\n","red");
        }
}

Util::disconnect();

sub maintenanceModeStoragePod {
	my ($pod,$ds,$op) = @_;

	my ($enter_msg_good,$enter_msg_bad,$exit_msg_good);
	if($op eq "enter") {
		$enter_msg_good = color("green") . "Successfully entering datastore into maintenance mode!" . color("reset") . "\n";
		$enter_msg_bad = color("red") . "Unable to put datastore into maintenance mode as datastore cluster \"" . $pod->name . "\" has <= 1 datastore!" . color("reset") . "\n\n";
	} else {
		$exit_msg_good = color("green") . "Successfully exiting datastore from maintenance mode!" . color("reset") . "\n";
	}

	my $datastore_view = Vim::find_entity_view(view_type => 'Datastore', filter => {'name' => $ds});
        unless($datastore_view) {
	        Util::disconnect();
                &print("Unable to locate datastore: \"$ds\"\n\n","red");
                exit 1;
        }

	my $entities = Vim::get_views(mo_ref_array => $pod->childEntity, properties => ['name']);
	if(@$entities gt 1) {
		if($op eq "enter") { 
			if($datastore_view->summary->maintenanceMode ne "normal") {
				&print("Datastore \"$ds\" is already in maintenance mode!\n","yellow");
			} else {
				if($pod->podStorageDrsEntry->storageDrsConfig->podConfig->defaultVmBehavior ne "automated") {
					&print("Datastore cluster automation level is set to \"manual\", you will need to manually apply SDRS recommendations!\n","yellow");
				}
				$datastore_view->DatastoreEnterMaintenanceMode();
				print $enter_msg_good;
			}
		} elsif($op eq "exit") {
			if($datastore_view->summary->maintenanceMode eq "normal")  {
				&print("Datastore \"$ds\" is not in maintenance mode!\n","yellow");
			} else {
				$datastore_view->DatastoreExitMaintenanceMode_Task();
				print $exit_msg_good;
			}
		}	
	} else {
		if($op eq "enter") {
			&print($enter_msg_bad,"red");
		}
	}
}

sub addAndRemoveDatastoreToPod {
	my ($pod,$op) = @_;

	my $podParentFolder;
	my @datastores_to_process = ();
	if($op eq "remove") {
		$podParentFolder = Vim::get_view(mo_ref => $pod->parent);
	}

	if($datastore_file) {
		&processDatastoreFile($datastore_file);
		foreach(@datastores) {
			my $datastore_view = Vim::find_entity_view(view_type => 'Datastore', filter => {'name' => $_});
			if($datastore_view) {
				push @datastores_to_process,$datastore_view;
			}
		}
	} elsif($datastore) {
		my $datastore_view = Vim::find_entity_view(view_type => 'Datastore', filter => {'name' => $datastore});
		unless($datastore_view) {
			Util::disconnect();
			&print("Unable to locate datastore: \"$datastore\"\n\n","red");
			exit 1;
		}
		push @datastores_to_process,$datastore_view;
	}
	
	my ($task,$msg);
	if($op eq "remove") {
		$task = $podParentFolder->MoveIntoFolder_Task(list => \@datastores_to_process);
		$msg = "Successfully removed datastore(s) from datastore cluster!\n";
	} else {
		$task = $pod->MoveIntoFolder_Task(list => \@datastores_to_process);
		$msg = "Successfully added datastore(s) to datastore cluster!\n";
	}
	&getStatus($task,$msg);
}

sub processDatastoreFile {
	my ($file) = @_;

	open(INPUTFILE, "$file") or die color("red") . "Failed to open file '$file'" . color("reset") . "\n\n";
	while(<INPUTFILE>) {
        	chomp;
	        s/#.*//; # Remove comments
        	s/^\s+//; # Remove opening whitespace
	        s/\s+$//;  # Remove closing whitespace
        	next unless length;
		push @datastores, $_;
	}
}

sub deleteStoragePod {
	my ($pod) = @_;

	my $task = $pod->Destroy_Task();
	&getStatus($task,"Successfully removed datstore cluster\n");
}

sub configureStoragePod {
	my ($pod) = @_;

	my $storageMgr = Vim::get_view(mo_ref => Vim::get_service_content()->storageResourceManager);

	#default value to disable SDRS if no user input
	if(!defined($enable_sdrs)) {
		$enable_sdrs = "true";
	}

	my $podConfigSpec = StorageDrsPodConfigSpec->new();
	my $sdrsSpaceConfig = StorageDrsSpaceLoadBalanceConfig->new();
	my $sdrsLBConfig = StorageDrsIoLoadBalanceConfig->new();
	if($enable_sdrs) {
		$podConfigSpec->{'enabled'} = $enable_sdrs;
	}
	if($sdrs_automation) {
		$podConfigSpec->{'defaultVmBehavior'} = $sdrs_automation;
	}
	if($enable_sdrs_iometric) {
		$podConfigSpec->{'ioLoadBalanceEnabled'} = $enable_sdrs_iometric;
	}
	if($sdrs_util_space) {
		$sdrsSpaceConfig->{'spaceUtilizationThreshold'} = $sdrs_util_space;
		$podConfigSpec->{'spaceLoadBalanceConfig'} = $sdrsSpaceConfig;
	}
	if($sdrs_latency) {
		$sdrsLBConfig->{'ioLatencyThreshold'} = $sdrs_latency;
		$podConfigSpec->{'ioLoadBalanceConfig'} = $sdrsLBConfig;
	}
	if($sdrs_util_diff) {
		$sdrsSpaceConfig->{'minSpaceUtilizationDifference'} = $sdrs_util_diff;
		$podConfigSpec->{'spaceLoadBalanceConfig'} = $sdrsSpaceConfig;
	}
	if($sdrs_evaluate_period) {
		$podConfigSpec->{'loadBalanceInterval'} = $sdrs_evaluate_period;
	}
	if($sdrs_imbal_thres) {
		$sdrsLBConfig->{'ioLoadImbalanceThreshold'} = $sdrs_imbal_thres;
                $podConfigSpec->{'ioLoadBalanceConfig'} = $sdrsLBConfig;
	}

	my $storagePodSpec = StorageDrsConfigSpec->new(podConfigSpec => $podConfigSpec);
	my $task = $storageMgr->ConfigureStorageDrsForPod_Task(pod => $pod, spec => $storagePodSpec, modify => 'true');
	&getStatus($task,"Successfully configured datastore cluster\n");
	$pod->ViewBase::update_view_data();
	&getStoragePodConfig($pod);
}

sub createStoragePod {
	my ($pod,$folder) = @_;

	my ($ret,$retView);
	eval {
                print "Creating datastore cluster: \"" . $pod . "\" ...\n";
                $ret = $folder->CreateStoragePod(name => $pod);
                $retView = Vim::get_view(mo_ref => $ret);
        };
        if($@) {
                &print("Errow creating datastore cluster: " . $@ . "\n\n","red");
                Util::disconnect();
                exit 1;
        }
	return $retView;
}

sub getDatacenterFolder {
	my ($dc) = @_;

	my $dcView = Vim::find_entity_view(view_type => 'Datacenter', filter => {'name' => $dc});
        unless($dcView) {
                Util::disconnect();
                &print("Unable to locate Datacenter: \"$dc\"\n\n","red");
                exit 1;
        }
        my $dcFolder = Vim::get_view(mo_ref => $dcView->datastoreFolder);
        if(!$dcFolder->isa('Folder')) {
		Util::disconnect();
                &print("Unable to locate Datacenter: \"$dc\" datastoreFolder\n\n","red");
		exit 1;
        }
	return $dcFolder;
}

sub getStoragePodConfig {
	my ($storagePod) =@_;

	&print("Datastore Cluster: " . $storagePod->name . "\n","cyan");
	my $entities = Vim::get_views(mo_ref_array => $storagePod->childEntity);
        foreach(@$entities) {
        	&print("\t" . $_->name . " (" . $_->summary->maintenanceMode . ")\n","magenta");
        }
        if($storagePod->podStorageDrsEntry) {
        	&print("\nConfigurations:\n","cyan");
                my $sdrsConfig = $storagePod->podStorageDrsEntry->storageDrsConfig->podConfig;
                &print("\t" . "SDRS Enabled: " . ($sdrsConfig->enabled ? "YES" : "NO") . "\n","green");
                &print("\t" . "SDRS Automation Level: " . $sdrsConfig->defaultVmBehavior . "\n","green");
                &print("\t" . "SDRS IO Metric Enabled: " . ($sdrsConfig->ioLoadBalanceEnabled ? "YES" : "NO") . "\n","green");
		if($sdrsConfig->loadBalanceInterval) {
			&print("\t" . "SDRS Load Balance Interval: " . $sdrsConfig->loadBalanceInterval . "\n","green");
		}
                if($sdrsConfig->spaceLoadBalanceConfig->spaceUtilizationThreshold) {
                	&print("\t" . "SDRS Space Util Threshold: " . $sdrsConfig->spaceLoadBalanceConfig->spaceUtilizationThreshold . " %\n","green");
                }
                if($sdrsConfig->ioLoadBalanceConfig->ioLatencyThreshold) {
                        &print("\t" . "SDRS IO Latency: " . $sdrsConfig->ioLoadBalanceConfig->ioLatencyThreshold . " ms\n","green");
                }
                if($sdrsConfig->spaceLoadBalanceConfig->minSpaceUtilizationDifference) {
                        &print("\t" . "SDRS Space Util Difference: " . $sdrsConfig->spaceLoadBalanceConfig->minSpaceUtilizationDifference . " %\n","green");
                }
                if($sdrsConfig->ioLoadBalanceConfig->ioLoadImbalanceThreshold) {
                        &print("\t" . "SDRS Imbalance Threshold: " . $sdrsConfig->ioLoadBalanceConfig->ioLoadImbalanceThreshold . "\n","green");
                }
	}
}

sub findStoragePod {
	my ($podName) = @_;

	my $pod_view = undef;

	if(defined($podName)) {
		$pod_view = Vim::find_entity_view(view_type => 'StoragePod', filter => {'name' => $podName});
	} else {
		$pod_view = Vim::find_entity_views(view_type => 'StoragePod');
	}
	return $pod_view;
}

sub getStatus {
        my ($taskRef,$message) = @_;

        my $task_view = Vim::get_view(mo_ref => $taskRef);
        my $taskinfo = $task_view->info->state->val;
        my $continue = 1;
        while ($continue) {
                my $info = $task_view->info;
                if ($info->state->val eq 'success') {
                        print color("green") . $message . color("reset");
                        return $info->result;
                        $continue = 0;
                } elsif ($info->state->val eq 'error') {
                        my $soap_fault = SoapFault->new;
                        $soap_fault->name($info->error->fault);
                        $soap_fault->detail($info->error->fault);
                        $soap_fault->fault_string($info->error->localizedMessage);
			Util::disconnect();
                        die color("red") . $soap_fault . color("reset") . "\n";
                }
                sleep 5;
                $task_view->ViewBase::update_view_data();
        }
}

sub validateSystem {
        my ($ver,$product) = @_;

        if(!grep(/$ver/,@supportedVersion)) {
                Util::disconnect();
                &print("Error: This script only supports vSphere \"@supportedVersion\" or greater!\n\n","red");
                exit 1;
        }

	if($product ne $productSupport) {
		Util::disconnect();
                &print("Error: This script only supports vSphere $productSupport!\n\n","red");
                exit 1;
	}
}

# prompt user taken from http://devdaily.com/perl/edu/articles/pl010005#comment-159
sub promptUser {
        my($prompt) = @_;
        print color("black","on_yellow") . "\t$prompt:" . color("reset") . " ";
        chomp(my $input = <STDIN>);
        return $input;
}

sub print {
	my ($msg,$color) = @_;

	print color($color) . $msg . color("reset");
}

=head1 NAME

datastoreClusterManagement.pl - Script to manager datastore clusters in vSphere

=head1 Examples

=over 4

=item List available datastore clusters

=item 

./datastoreClusterManagement.pl --server [VCENTER_SERVER] --username [USERNAME] --operation list

=item Query a specific datastore cluster

=item

./datastoreClusterManagement.pl --server [VCENTER_SERVER] --username [USERNAME] --operation query --pod [DATASTORE_CLUSTER]

=item Create datastore cluster

=item

./datastoreClusterManagement.pl --server [VCENTER_SERVER] --username [USERNAME] --operation create --pod [DATASTORE_CLUSTER] --datacenter [DATACENTER] --enable_sdrs [true|false] --enable_sdrs_iometric [true|false] --sdrs_automation automated [true|false] --sdrs_evaluate_period [EVAL_PERIOD] --sdrs_imbal_thres [IMBAL_THRES] --sdrs_latency [LAT] --sdrs_util_diff [UTIL_DIFF] --sdrs_util_space [UTIL_SPACE} --datastore|--datastore_file

=item

=item Delete datastore cluster

./datastoreClusterManagement.pl --server [VCENTER_SERVER] --username [USERNAME] --operation delete --pod [DATASTORE_CLUSTER]

=item

=item Add datastore to datastore cluster

./datastoreClusterManagement.pl --server [VCENTER_SERVER] --username [USERNAME] --operation add_datastore --pod [DATASTORE_CLUSTER] --datastore|--dastore_file

=item

=item Remove datastore from datastore cluster

./datastoreClusterManagement.pl --server [VCENTER_SERVER] --username [USERNAME] --operation remove_datastore --pod [DATASTORE_CLUSTER] --datastore|--dastore_fil
e

=item

=item Datastore enter maintenance mode

./datastoreClusterManagement.pl --server [VCENTER_SERVER] --username [USERNAME] --operation ent_maint --pod [DATASTORE_CLUSTER] --datastore|--dastore_file

=item

=item Datastore exit maintenance mode

./datastoreClusterManagement.pl --server [VCENTER_SERVER] --username [USERNAME] --operation exi_maint --pod [DATASTORE_CLUSTER] --datastore|--dastore_file

=item


=back

=head1 SUPPORT

vSphere 5.0

=head1 AUTHORS

William Lam, http://www.virtuallyghetto.com/

=cut
