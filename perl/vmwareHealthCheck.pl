#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://communities.vmware.com/docs/DOC-9420

use strict;
use warnings;
use Math::BigInt;
use Tie::File;
use POSIX qw/mktime/;
use Getopt::Long;
use VMware::VIRuntime;
use VMware::VILib;

####################################
#  resource consumption warnings
####################################
# yellow < 30 %
my $yellow_warn = 30;

# orange < 15 %
my $orange_warn = 15;

# red < 10%
my $red_warn = 10;

######################################
#  vm snapshot age warnings
######################################
# yellow < 15 days
my $snap_yellow_warn = 15;

# orange < 30 days
my $snap_orange_warn = 30;

# red < 60 days+
my $snap_red_warn = 60;


########### DO NOT MODIFY PAST HERE ###########

################################
# VERSION
################################
my $version = "v0.9.5";
$Util::script_version = $version;

################################
# DEMO MODE
# 0 = no, 1 = yes
################################
my $enable_demo_mode = 0;

################
#GLOBAL VARS
################
my $opt_type;
my $host_type;
my $host_view;
my $host_views;
my $cluster_view;
my $cluster_views;
my $cluster_count = 0;
my $report_name;
my @snapshot_vms = ();
my @connected_cdrom_vms = ();
my @connected_floppy_vms = ();
my @rdm_vms = ();
my @npiv_vms = ();
my %net_vms = ();
my %vms_storage = ();
my %vms_disks = ();
my $execute_flag = 0;
my $start_time;
my $end_time;
my $run_time;
my $my_time;
my @jump_tags = ();
my %cdp_enabled = ();
my @hba_list = ();
my @health_list = ();
my @nic_list = ();
my @hosts_seen = ();
my $datacenter_name;
my @vm_delta_warn = ();
my $hostd_log_print;
my $randomHostName;
my $content;
my %portgroup_row_info = ();
my $cdp_string = "";

my %opts = (
	cluster => {
      	type => "=s",
      	help => "The name of a vCenter cluster",
      	required => 0,
   	},
	datacenter => {
	type => "=s",
	help => "The name of a vCenter datacenter",
	required => 0,
	},
   	type => {
      	type => "=s",
      	help => "Type: [vcenter|datacenter|cluster|host|detail-hosts|vmfrag]\n",
      	required => 1,
   	},
	report => {
	type => "=s",
	help => "The name of the report to output. Please at \".html\" extension",
	required => 0,
	},
	logcount => {
	type => "=s",
        help => "The number of lines to output from hostd logs",
        required => 0,
        },
);
# validate options, and connect to the server
Opts::add_options(%opts);

# validate options, and connect to the server
Opts::parse();
Opts::validate();
Util::connect();

############################
# PARSE COMMANDLINE OPTIONS
#############################
if (Opts::option_is_set ('type')) {
	# get ServiceContent
       	$content = Vim::get_service_content();
	$host_type = $content->about->apiType;
	$opt_type = Opts::get_option('type');

	####################
	# SINGLE ESX HOST
	####################
	if( ($opt_type eq 'host') && (!Opts::option_is_set('cluster')) && ($host_type eq 'HostAgent') ) {
		$host_view = Vim::find_entity_views(view_type => 'HostSystem');
		if (!$host_view) {
			die "ESX/ESXi host was not found\n";
		}
	}
	#####################
	# vCENTER + CLUSTER
	#####################
	elsif( ($opt_type eq 'cluster') && ($host_type eq 'VirtualCenter') ) {
		if ( Opts::option_is_set('cluster') ) {
			my $cluster_name = Opts::get_option('cluster');
			$cluster_view = Vim::find_entity_view(view_type => 'ClusterComputeResource',filter => { name => $cluster_name });

			if(!$cluster_view) {
				die "Cluster: \"$cluster_name\" was not found\n";
			}
		}
		else {
			Fail("\n--cluster parameter required with the name of a valid vCenter Cluster\n\n");
		}
	}
        ########################
        # vCENTER + DATACENTER
        ########################
        elsif( ($opt_type eq 'datacenter') && ($host_type eq 'VirtualCenter') ) {
                if ( Opts::option_is_set('datacenter') ) {
                        $datacenter_name = Opts::get_option('datacenter');
			my $datacenter_view = Vim::find_entity_view(view_type => 'Datacenter',filter => { name => $datacenter_name});
			if(!$datacenter_view) {
				die "Datacenter: \"$datacenter_name\" was not found\n";
			}
                        $cluster_views = Vim::find_entity_views(view_type => 'ClusterComputeResource',begin_entity => $datacenter_view);

                        if(!$cluster_views) {
                                die "No clusters were found in this datacenter\n";
                        }
                }
                else {
                        Fail("\n--datacenter parameter required with the name of a valid vCenter Datacenter\n\n");
                }
        }
        #########################
        # vCENTER HOST DETAIL
        #########################
        elsif( ($opt_type eq 'detail-hosts') && (!Opts::option_is_set('cluster')) && ($host_type eq 'VirtualCenter') ) {
                $cluster_views = Vim::find_entity_views(view_type => 'ClusterComputeResource');
                Fail ("No clusters found.\n") unless (@$cluster_views);
        }
	##################
	# vCENTER ALL
	##################
	elsif( ($opt_type eq 'vcenter') && (!Opts::option_is_set('cluster')) && ($host_type eq 'VirtualCenter') ) {
		$cluster_views = Vim::find_entity_views(view_type => 'ClusterComputeResource');
		Fail ("No clusters found.\n") unless (@$cluster_views);
	}
        #######################################
        # VM DISK INFO INDIVIDUAL HOSTS ONLY
        ######################################
	elsif( ($opt_type eq 'vmfrag') && (!Opts::option_is_set('cluster')) && ($host_type eq 'HostAgent') ) { 
		$host_view = Vim::find_entity_views(view_type => 'HostSystem');
                if (!$host_view) {
                        die "ESX/ESXi host was not found\n";
                }	
	} else { die "Invalid Input, ensure your selection is one of the supported use cases on the VMTN Doc\n\n\tServer: vCenter => [vcenter|datacenter|cluster|detail-hosts]\n\tServer: ESX/ESXi Host => [host|vmfrag]\n"; }
	

	#if report name is not specified, default output
	if (Opts::option_is_set ('report')) {
		$report_name = Opts::get_option('report');
	}
	else {
		$report_name = "vmware_health_report.html";
	}

	#if use case is with hostd logs, set log count or default to 15
	if( Opts::option_is_set('logcount') ) {
 	       $hostd_log_print = Opts::get_option('logcount');
        } else { $hostd_log_print = 15; }
}

### CODE START ###

#################################
# PRINT HTML HEADER/CSS
#################################
printStartHeader();

#########################################
# PRINT vCENTER or HOST BUILD/SUMMARY 
#########################################
printBuildSummary();

#########################################
# PRINT vCENTER INFO
#########################################
if ($opt_type eq 'vcenter') {
	foreach my $cluster (@$cluster_views) {
		$cluster_count += 1;
		printClusterSummary($cluster);	
		my $hosts = Vim::get_views (mo_ref_array => $cluster->host);
		if(@$hosts) {
			printHostHardwareInfo($hosts);
			printHostLun($hosts);
			printHostDatastoreInfo($hosts);
			printPG();
			printHostVM($hosts);
			printVMDatastore();
			printVMNetwork();
			printVMSnapshot();
			printVMSnapshotDeltaOlderThan();
			printVMNPIV();
			printVMRDM();
			printVMCDrom();
			printVMFloppy();
			cleanUp();
		}
	}
}
#########################################
# PRINT SPECIFIC DATACENTER INFO
#########################################
elsif ($opt_type eq 'datacenter') {
	printDatacenterName($datacenter_name);
        foreach my $cluster (@$cluster_views) {
                $cluster_count += 1;
                printClusterSummary($cluster);
                my $hosts = Vim::get_views (mo_ref_array => $cluster->host);
                if(@$hosts) {
                        printHostHardwareInfo($hosts);
                        printHostLun($hosts);
                        printHostDatastoreInfo($hosts);
			printPG();
                        printHostVM($hosts);
                        printVMDatastore();
                        printVMNetwork();
                        printVMSnapshot();
			printVMSnapshotDeltaOlderThan();
                        printVMNPIV();
                        printVMRDM();
                        printVMCDrom();
                        printVMFloppy();
                        cleanUp();
                }
        }
}
#########################################
# PRINT SPECIFIC CLUSTER INFO
#########################################
elsif ($opt_type eq 'cluster') {
	$cluster_count += 1;
	printClusterSummary($cluster_view);
	my $hosts = Vim::get_views (mo_ref_array => $cluster_view->host);
	if(@$hosts) {
		printHostHardwareInfo($hosts);
		printHostLun($hosts);
		printHostDatastoreInfo($hosts);
		printPG();
		printHostVM($hosts);
		printVMDatastore();
		printVMNetwork();
        	printVMSnapshot();
		printVMSnapshotDeltaOlderThan();
		printVMNPIV();
        	printVMRDM();
        	printVMCDrom();
		printVMFloppy();
		cleanUp();
	}
}
#########################################
# PRINT SINGLE HOST INFO
#########################################
elsif ($opt_type eq 'host' ) {
	printHostHardwareInfo($host_view);
	printHostLun($host_view);
	printHostDatastoreInfo($host_view);
	printHostPortgroup($host_view);
	printHostVM($host_view);
	queryVMDisk($host_view);
	printVMDatastore();
        printVMNetwork();
        printVMSnapshot();
	printVMSnapshotDeltaOlderThan();
	printVMNPIV();
        printVMRDM();
        printVMCDrom();
	printVMFloppy();
	cleanUp();
}
#########################################
# PRINT DETAIL HOSTS INFO
#########################################
elsif ($opt_type eq 'detail-hosts') {
        foreach my $cluster (@$cluster_views) {
                $cluster_count += 1;
                printClusterSummary($cluster);
                my $hosts = Vim::get_views (mo_ref_array => $cluster->host);
                if(@$hosts) {
			printHostHardwareInfo($hosts);
			printHostLun($hosts);
		        printHostDatastoreInfo($hosts);
			printPG();
        		printVMSnapshot();
        		printVMSnapshotDeltaOlderThan();
        		printVMNPIV();
        		printVMRDM();
        		printVMCDrom();
        		printVMFloppy();
			cleanUp();
		}
	}
}
#########################################
# PRINT VM DISK INFO
#########################################
elsif ($opt_type eq 'vmfrag') {
	queryVMDisk($host_view);
	cleanUp();
}

#################################
# CLOSE HTML REPORT
#################################
printCloseHeader();

Util::disconnect();

### CODE END ###

###########################
#
# HELPER FUNCTIONS 
#
###########################

sub queryVMDisk {
	my ($host_view) = @_;
	foreach my $host (@$host_view) {
		my $vm_views = Vim::get_views (mo_ref_array => $host->vm);
		if($opt_type eq 'vmfrag') {
			push @jump_tags,"<a href=\"#VM(s) VMDK Disk Information\">VM(s) VMDK Disk Information</a><br>\n";
		} else {
			push @jump_tags,"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href=\"#VM(s) VMDK Disk Information\">VM(s) VMDK Disk Information</a><br>\n";
		}	
		print REPORT_OUTPUT "\n<a name=\"VM(s) VMDK Disk Information\"></a>\n";
                print REPORT_OUTPUT "<H3>VM(s) VMDK Disk Information:</H3>\n";
                print REPORT_OUTPUT "<table border=1>\n";
                print REPORT_OUTPUT "<tr><th>VM</th><th>FRAGMENTATION</th><th>VMDK</th><th>DISK CYLINDER</th><th>DISK HEAD</th><th>DISK SECTOR</th><th>UUID</th></tr>\n";
                foreach my $vm (@$vm_views) {
			#skip if vm is disconnected
			next if(!defined($vm->layout));
			my $disks = $vm->layout->disk;
        		my $vdm_mgr = Vim::get_view(mo_ref => Vim::get_service_content()->virtualDiskManager);
        		foreach(@$disks) {
        			my $disk_files = $_->diskFile;
				my $disk_string = "";
               			foreach(@$disk_files) {
                        		eval { $vdm_mgr->QueryVirtualDiskFragmentation(name => $_); };
					if(!$@) {
						my $disk_frag = $vdm_mgr->QueryVirtualDiskFragmentation(name => $_);
						my $disk_geom = $vdm_mgr->QueryVirtualDiskGeometry(name => $_);
						my $disk_uuid = $vdm_mgr->QueryVirtualDiskUuid(name => $_);
						if(!defined($disk_frag)) { $disk_frag = "N/A"; }
						print REPORT_OUTPUT "<tr><td>",$vm->config->name,"</td><td>".$disk_frag."</td><td>".$_."</td><td>".$disk_geom->cylinder."</td><td>".$disk_geom->head."</td><td>".$disk_geom->sector."</td><td>".$disk_uuid."</td>","</tr>\n";
					}
        	        	}
        		}
		}
		print REPORT_OUTPUT "</table>\n";
	}
}

sub printVMNPIV {
        ###########################
        # PRINT NPIV INFO
        ###########################
        if(@npiv_vms) {
                my $npiv_count = $#npiv_vms;
                $npiv_count += 1;
		if($opt_type eq 'detail-hosts') {
                        push @jump_tags,"<a href=\"#VM(s) w/NPIV enabled-$cluster_count\">VM(s) w/NPIV enabled</a><br>\n";
		} else { push @jump_tags,"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href=\"#VM(s) w/NPIV enabled-$cluster_count\">VM(s) w/NPIV enabled</a><br>\n"; }
		print REPORT_OUTPUT "\n<a name=\"VM(s) w/NPIV enabled-$cluster_count\"></a>\n";
                print REPORT_OUTPUT "<H3>$npiv_count VM(s) w/NPIV enabled:</H3>\n";
                print REPORT_OUTPUT "<table border=1>\n";
                print REPORT_OUTPUT "<tr><th>VM</th><th>NPIV NODE WWN</th><th>NPIV PORT WWN</th><th>GENERATED FROM</th></tr>\n";
                foreach (@npiv_vms) {
                        print REPORT_OUTPUT "<tr>",$_,"</tr>\n";
                }
                print REPORT_OUTPUT "</table>\n";
        }
        @npiv_vms = ();
}

sub printVMSnapshotDeltaOlderThan {
        ###########################
        # PRINT DELTA INFO
        ###########################
	if(@vm_delta_warn) {
		my $snap_delta_count = $#vm_delta_warn;
		$snap_delta_count +=1;
		if($opt_type eq 'detail-hosts') {
                        push @jump_tags,"<a href=\"#VM(s) w/Snapshot Delta(s) Older Than $snap_yellow_warn+ Days-$cluster_count\">VM(s) w/Snapshot Delta(s) Older Than $snap_yellow_warn+ days</a><br>\n";
		} else { push @jump_tags,"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href=\"#VM(s) w/Snapshot Delta(s) Older Than $snap_yellow_warn+ Days-$cluster_count\">VM(s) w/Snapshot Delta(s) Older Than $snap_yellow_warn+ days</a><br>\n"; }
                print REPORT_OUTPUT "\n<a name=\"VM(s) w/Snapshot Delta(s) Older Than $snap_yellow_warn+ Days-$cluster_count\"></a>\n";
                print REPORT_OUTPUT "<H3>$snap_delta_count VM(s) w/Snapshot Delta(s) Older Than $snap_yellow_warn+ Days:</H3>\n";
		print REPORT_OUTPUT "<table border=1><tr><td bgcolor=\"#CCCCCC\"><b>COLOR LEGEND</b></td><td bgcolor=\"yellow\"><b>YELLOW > $snap_yellow_warn days</b></td><td bgcolor=\"orange\"><b>ORANGE > $snap_orange_warn days</b></td><td bgcolor=\"red\"><b>RED > $snap_red_warn days</b></td></tr></table>\n";
                print REPORT_OUTPUT "<table border=1>\n";
                print REPORT_OUTPUT "<tr><th>DATASTORE</th><th>VM DELTA</th><th>AGE</th><th>SIZE</th><th>CREATED</th></tr>\n";
                foreach(@vm_delta_warn) {
			print REPORT_OUTPUT "<tr>",$_,"</tr>\n";
                }
		print REPORT_OUTPUT "</table>\n";
        }
	@vm_delta_warn = ();
}

sub printVMSnapshot {
        ###########################
        # PRINT SNAPSHOT INFO
        ###########################
        if(@snapshot_vms) {
                my $snap_count = $#snapshot_vms;
                $snap_count += 1;
		if($opt_type eq 'detail-hosts') {

                        push @jump_tags,"<a href=\"#VM(s) w/Snapshot(s)-$cluster_count\">VM(s) w/Snapshot(s)</a><br>\n";
		} else { push @jump_tags,"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href=\"#VM(s) w/Snapshot(s)-$cluster_count\">VM(s) w/Snapshot(s)</a><br>\n"; }
		print REPORT_OUTPUT "\n<a name=\"VM(s) w/Snapshot(s)-$cluster_count\"></a>\n";
                print REPORT_OUTPUT "<H3>$snap_count VM(s) w/Snapshot(s):</H3>\n";
                print REPORT_OUTPUT "<table border=1>\n";
                print REPORT_OUTPUT "<tr><th>VM</th><th>SNAPSHOT NAME</th><th>SNAPSHOT DESC</th><th>CREATED</th><th>STATE</th><th>QUIESCED</th></tr>\n";
                foreach (@snapshot_vms) {
                        print REPORT_OUTPUT "<tr>",$_,"</tr>\n";
                }
                print REPORT_OUTPUT "</table>\n";
        }
        @snapshot_vms = ();
}

sub printVMRDM {
        ###########################
        # PRINT RDM INFO
        ###########################
        if(@rdm_vms) {
                my $rdm_count = $#rdm_vms;
                $rdm_count += 1;
		if($opt_type eq 'detail-hosts') {
                        push @jump_tags,"<a href=\"#VM(s) w/RDM(s)-$cluster_count\">VM(s) w/RDM(s)</a><br>\n";
		} else { push @jump_tags,"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href=\"#VM(s) w/RDM(s)-$cluster_count\">VM(s) w/RDM(s)</a><br>\n"; }
		print REPORT_OUTPUT "\n<a name=\"VM(s) w/RDM(s)-$cluster_count\"></a>\n";
                print REPORT_OUTPUT "<H3>$rdm_count VM(s) w/RDM(s):</H3>\n";
                print REPORT_OUTPUT "<table border=1>\n";
                print REPORT_OUTPUT "<tr><th>VM</th><th>COMPAT MODE</th><th>DEVICE</th><th>DISK MODE</th><th>LUN UUID</th><th>VIRTUAL DISK UUID</th></tr>\n";
                foreach (@rdm_vms) {
                        print REPORT_OUTPUT "<tr>",$_,"</tr>\n";
                }
                print REPORT_OUTPUT "</table>\n";
        }
        @rdm_vms = ();
}

sub printVMCDrom {
        ###########################
        # PRINT CDROM INFO
        ###########################
        if(@connected_cdrom_vms) {
                my $cdrom_count = $#connected_cdrom_vms;
                $cdrom_count += 1;
		if($opt_type eq 'detail-hosts') {
                        push @jump_tags,"<a href=\"#VM(s) w/connected CD-ROM(s)-$cluster_count\">VM(s) w/connected CD-ROM(s)</a><br>\n";
		} else { push @jump_tags,"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href=\"#VM(s) w/connected CD-ROM(s)-$cluster_count\">VM(s) w/connected CD-ROM(s)</a><br>\n"; }
		print REPORT_OUTPUT "\n<a name=\"VM(s) w/connected CD-ROM(s)-$cluster_count\"></a>\n";
                print REPORT_OUTPUT "<H3>$cdrom_count VM(s) w/connected CD-ROM(s):</H3>\n";
                print REPORT_OUTPUT "<table border=1>\n";
                print REPORT_OUTPUT "<tr><th>VM</th></tr>\n";
                foreach (@connected_cdrom_vms) {
                                print REPORT_OUTPUT "<tr><td>",$_,"</td></tr>\n";
                }
                print REPORT_OUTPUT "</table>\n";
        }
        @connected_cdrom_vms = ();
}

sub printVMFloppy {
        ###########################
        # PRINT FLOPPY INFO
        ###########################
        if(@connected_floppy_vms) {
                my $floppy_count = $#connected_floppy_vms;
                $floppy_count += 1;
		if($opt_type eq 'detail-hosts') {
                        push @jump_tags,"<a href=\"#VM(s) w/connected Floppy(s)-$cluster_count\">VM(s) w/connected Floppy(s)</a><br>\n";
                } else {
		push @jump_tags,"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href=\"#VM(s) w/connected Floppy(s)-$cluster_count\">VM(s) w/connected Floppy(s)</a><br>\n"; }
		print REPORT_OUTPUT "\n<a name=\"VM(s) w/connected Floppy(s)-$cluster_count\"></a>\n";
                print REPORT_OUTPUT "<H3>$floppy_count VM(s) w/connected Floppy(s):</H3>\n";
                print REPORT_OUTPUT "<table border=1>\n";
                print REPORT_OUTPUT "<tr><th>VM</th></tr>\n";
                foreach (@connected_floppy_vms) {
                                print REPORT_OUTPUT "<tr><td>",$_,"</td></tr>\n";
                }
                print REPORT_OUTPUT "</table>\n";
        }
        @connected_floppy_vms = ();
}

sub printVMNetwork {
        ####################################
        # PRINT VM NETWORK SUMMARY
        ####################################
        if(%net_vms) {
		push @jump_tags,"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href=\"#VM(s) Network Summary-$cluster_count\">VM(s) Network Summary</a><br>\n";
		print REPORT_OUTPUT "\n<a name=\"VM(s) Network Summary-$cluster_count\"></a>\n";
                print REPORT_OUTPUT "<H3>VM(s) Network Summary:</H3>\n";
                print REPORT_OUTPUT "<table border=1>\n";
                print REPORT_OUTPUT "<tr><th>VM</th><th>IP(s)</th><th>MAC ADDRESS</th><th>PORTGROUP</th><th>CONNECTED</th></tr>\n";
                foreach ( sort keys %net_vms ) {
                        my $vm_net = $net_vms{$_};
                        print REPORT_OUTPUT "<tr><td>",$_,"</td>",$vm_net,"</tr>\n";
                }
                print REPORT_OUTPUT "</table>\n";
        }
        %net_vms = ();
}

sub printVMDatastore {
	####################################
        # PRINT VM DISK/DATASTORE SUMMARY
        ####################################
        if(%vms_storage) {
		push @jump_tags,"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href=\"#VM(s) Storage Summary-$cluster_count\">VM(s) Storage Summary</a><br>\n";
		print REPORT_OUTPUT "\n<a name=\"VM(s) Storage Summary-$cluster_count\"></a>\n";
                print REPORT_OUTPUT "<H3>VM(s) Storage Summary:</H3>\n";
		print REPORT_OUTPUT "<table border=1><tr><td bgcolor=\"#CCCCCC\"><b>COLOR LEGEND</b></td><td bgcolor=\"yellow\"><b>YELLOW < $yellow_warn %</b></td><td bgcolor=\"orange\"><b>ORANGE < $orange_warn %</b></td><td bgcolor=\"red\"><b>RED < $red_warn %</b></td></tr></table>\n";
                print REPORT_OUTPUT "<table border=1>\n";
                print REPORT_OUTPUT "<tr><th>VM</th><th>DATASTORE</th><th><table border=1><tr><td><b>DISK INFO</b></td><td><b>FREE SPACE</b></td><td><b>CAPACITY</b></td><td><b>% FREE</b></td></tr></table></th></tr>\n";
                foreach ( sort keys %vms_storage ) {
                        my $vm_ds = $vms_storage{$_};
                        my $vm_disk = $vms_disks{$_};
                        if(!$vm_disk) {
                                $vm_disk = "<td>not available</td>";
                        }
                        print REPORT_OUTPUT "<tr><td>",$_,"</td><td>",$vm_ds,"</td>",$vm_disk,"</tr>\n";
                }
                print REPORT_OUTPUT "</table>\n";
        }
        %vms_storage = ();
}

sub printLimitedVMInfo {
	my ($host) = @_;
	my $hostName;
        if($enable_demo_mode eq 1) { $hostName = $randomHostName;
        } else { $hostName = $host->summary->config->name; }

        ###########################
        # PRINT LIMITED VM SUMMARY
        ###########################
	my $seen_vm = 0;
	push @jump_tags,"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href=\"#$hostName Virtual Machines\">Virtual Machines</a><br>\n";
        print REPORT_OUTPUT "\n<a name=\"$hostName Virtual Machines\"></a>\n";
        print REPORT_OUTPUT "<H3>Virtual Machines:</H3>\n";
        print REPORT_OUTPUT "<table border=1>\n";
        print REPORT_OUTPUT "<tr><th>VM</th><th>HOSTNAME</th><th>POWER STATE</th><th># OF DISK(s)</th><th># OF vCPU(s)</th><th>MEM</th><th>VMX LOCATION</th></tr>\n";
		my $vm_views = Vim::get_views (mo_ref_array => $host->vm);
		foreach my $vm (@$vm_views) {
			#skip if vm is disconnected
                        next if(!defined($vm->config));
			print REPORT_OUTPUT "<tr>";
                        if($enable_demo_mode eq 1) {
                                print REPORT_OUTPUT "<td>",$vm->config->name,"</td>";
				print REPORT_OUTPUT "<td>HIDE ME!</td>";
                        }
                        else {
                                print REPORT_OUTPUT "<td>",$vm->config->name,"</td>";
                                if (defined($vm->guest->hostName)) {print REPORT_OUTPUT "<td>",$vm->guest->hostName,"</td>"; }
                                else { print REPORT_OUTPUT "<td>UNKNOWN</td>"; }
                        }
                        $seen_vm = 1;
                        print REPORT_OUTPUT "<td>",$vm->runtime->powerState->val,"</td>";

			#retrieve vms w/connected CDROM/FLOPPY
                        my $devices = $vm->config->hardware->device;
                        my $numOfDisks = 0;
                        foreach my $device (@$devices) {
                                my $device_name = $device->deviceInfo->label;
                                if ( ($device->isa('VirtualCdrom')) && ($device->connectable->connected == 1) ) {
                                        if($seen_vm eq 1) {
                                                push @connected_cdrom_vms,$vm->config->name;
                                        }
                                }
                                if ( ($device->isa('VirtualFloppy')) && ($device->connectable->connected == 1) ) {
                                        if($seen_vm eq 1) {
                                                push @connected_floppy_vms,$vm->config->name;
                                        }
                                }
                                if ( ($device->isa('VirtualDisk')) && ($device->backing->isa('VirtualDiskRawDiskMappingVer1BackingInfo')) ) {
                                        if($seen_vm eq 1) {
                                                my $vm_name = $vm->config->name;
                                                my $compat_mode = $device->backing->compatibilityMode;
                                                my $vmhba = $device->backing->deviceName;
                                                my $disk_mode = $device->backing->diskMode;
                                                my $lun_uuid = $device->backing->lunUuid;
                                                my $vm_uuid = $device->backing->uuid;
                                                my $rdm_string = "";
                                                if(!$vm_uuid) { $vm_uuid="N/A"; }
                                                $rdm_string="<td>$vm_name</td><td>$compat_mode</td><td>$vmhba</td><td>$disk_mode</td><td>$lun_uuid</td><td>$vm_uuid</td>";
                                                push @rdm_vms,$rdm_string;
                                        }
                                }
                                if($device->isa('VirtualDisk')) { $numOfDisks += 1; }
                        }

			print REPORT_OUTPUT "<td>",$numOfDisks,"</td>";
                        if (defined($vm->summary->config->numCpu)) {print REPORT_OUTPUT "<td>",$vm->summary->config->numCpu,"</td>"; }
                        else {print REPORT_OUTPUT "<td>UNKNOWN</td>"; }
                        if (defined($vm->summary->config->memorySizeMB)) {print REPORT_OUTPUT "<td>",prettyPrintData($vm->summary->config->memorySizeMB,'M'),"</td>"; }
                        else {print REPORT_OUTPUT "<td>UNKNOWN</td>"; }
			print REPORT_OUTPUT "<td>",$vm->config->files->vmPathName,"</td>";
			print REPORT_OUTPUT "</tr>\n";

			#retrieve vms w/NPIV
                        my $nwwns = $vm->config->npivNodeWorldWideName;
                        my $pwwns = $vm->config->npivPortWorldWideName;
                        my $n_type = $vm->config->npivWorldWideNameType;
                        if( ($nwwns) && ($seen_vm eq 1) ) {
                                my $npiv_string = "";
                                my $n_vm = $vm->config->name;
                                $npiv_string .= "<td>$n_vm</td>";
                                $npiv_string .= "<td>";
                                foreach (@$nwwns) {
                                        my $nwwn = (Math::BigInt->new($_))->as_hex();
                                        $nwwn =~ s/^..//;
                                        $nwwn = join(':', unpack('A2' x 8, $nwwn));
                                        if($enable_demo_mode eq 1) {
                                                $npiv_string .= "XX:XX:XX:XX:XX:XX:XX:XX<br>";
                                        }
                                        else {
                                                $npiv_string .= "$nwwn<br>";
                                        }
                                }
                                $npiv_string .= "</td><td>";
                                foreach (@$pwwns) {
                                        my $pwwn = (Math::BigInt->new($_))->as_hex();
                                        $pwwn =~ s/^..//;
                                        $pwwn = join(':', unpack('A2' x 8, $pwwn));
                                        if($enable_demo_mode eq 1) {
                                                $npiv_string .= "XX:XX:XX:XX:XX:XX:XX:XX<br>";
                                        }
                                        else {
                                                $npiv_string .= "$pwwn<br>";
                                        }
                                }
                                if($n_type eq 'vc') { $n_type = "Virtual Center"; }
                                elsif($n_type eq 'external') { $n_type = "External Source"; }
                                elsif($n_type eq 'host') { $n_type = "ESX or ESXi"; }
                                $npiv_string .= "</td><td>$n_type</td>";
                                push @npiv_vms,$npiv_string;
                        }

                        #retrieve vms w/snapshots
                        if(defined($vm->snapshot)) {
                                if($seen_vm eq 1) {
                                        print_tree ($vm->config->name,$vm->snapshot->currentSnapshot, $vm->snapshot->rootSnapshotList);
                                }
                        }
		}
		print REPORT_OUTPUT "</table>\n";
}

sub printHostVM {
	my ($local_hosts) = @_;
        ###########################
        # PRINT VM SUMMARY
        ###########################
        my $seen_vm = 0;
	push @jump_tags,"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href=\"#Virtual Machines-$cluster_count\">Virtual Machines</a><br>\n";
	print REPORT_OUTPUT "\n<a name=\"Virtual Machines-$cluster_count\"></a>\n";
        print REPORT_OUTPUT "<H3>Virtual Machines:</H3>\n";
        print REPORT_OUTPUT "<table border=1>\n";
        print REPORT_OUTPUT "<tr><th>ESX&#047;ESXi HOST</th><th>VM</th><th>HOSTNAME</th><th>VM STATUS</th><th>CONNECTION STATE</th><th>POWER STATE</th><th># OF DISK(s)</th><th># OF vCPU(s)</th><th>MEM</th><th>CPU USAGE</th><th>MEM USAGE</th><th>CPU RESRV</th><th>MEM RESRV</th><th># OF vNIC(s)</th><th>VMware Tools Status</th><th>TIME SYNC w/HOST</th><th>TOOLS VER</th><th>TOOLS UPGRADE POLICY</th><th>TOOLS MOUNTED</th><th>GUEST OS</th><th>IS TEMPLATE</th></tr>\n";
        foreach my $host (@$local_hosts) {
                my $vm_views = Vim::get_views (mo_ref_array => $host->vm);
                #clear seen vms hash
                foreach my $vm (@$vm_views) {
			#skip if vm is disconnected
			next if(!defined($vm->config));
                        print REPORT_OUTPUT "<tr>";
			my $vm_host_view = Vim::get_view(mo_ref=>$vm->summary->runtime->host, properties => ['name']);
			if($enable_demo_mode eq 1) {
                        	print REPORT_OUTPUT "<td>HIDE ME!</td>";
				print REPORT_OUTPUT "<td>",$vm->config->name,"</td>"; 
				print REPORT_OUTPUT "<td>HIDE ME!</td>";
			}
			else {
				print REPORT_OUTPUT "<td>",$vm_host_view->name,"</td>";
                                print REPORT_OUTPUT "<td>",$vm->config->name,"</td>";
				if (defined($vm->guest->hostName)) {print REPORT_OUTPUT "<td>",$vm->guest->hostName,"</td>"; }
                        	else { print REPORT_OUTPUT "<td>UNKNOWN</td>"; }
			}
                        $seen_vm = 1;
                        my $vm_health = $vm->summary->overallStatus->val;
                        if ($vm_health eq 'green') { print REPORT_OUTPUT "<td bgcolor=\"green\">VM is OK</td>"; }
                        elsif ($vm_health eq 'red') { print REPORT_OUTPUT "<td bgcolor=\"red\">VM has a problem</td>"; }
                        elsif ($vm_health eq 'yellow') { print REPORT_OUTPUT "<td bgcolor=\"yellow\">VM<might have a problem</td>"; }
                        else { print REPORT_OUTPUT "<td bgcolor=\"gray\">UNKNOWN</td>"; }
                        print REPORT_OUTPUT "<td>",$vm->runtime->connectionState->val,"</td>";
                        print REPORT_OUTPUT "<td>",$vm->runtime->powerState->val,"</td>";

			my $numOfDisks;
			#retrieve vms w/connected CDROM/FLOPPY
                        my $devices = $vm->config->hardware->device;
                        foreach my $device (@$devices) {
                                my $device_name = $device->deviceInfo->label;
                                if ( ($device->isa('VirtualCdrom')) && ($device->connectable->connected == 1) ) {
                                        if($seen_vm eq 1) {
                                                push @connected_cdrom_vms,$vm->config->name;
                                        }
                                }
                                if ( ($device->isa('VirtualFloppy')) && ($device->connectable->connected == 1) ) {
                                        if($seen_vm eq 1) {
                                                push @connected_floppy_vms,$vm->config->name;
                                        }
                                }
                                if ( ($device->isa('VirtualDisk')) && ($device->backing->isa('VirtualDiskRawDiskMappingVer1BackingInfo')) ) {
                                        if($seen_vm eq 1) {
                                                my $vm_name = $vm->config->name;
                                                my $compat_mode = $device->backing->compatibilityMode;
                                                my $vmhba = $device->backing->deviceName;
                                                my $disk_mode = $device->backing->diskMode;
                                                my $lun_uuid = $device->backing->lunUuid;
                                                my $vm_uuid = $device->backing->uuid;
                                                my $rdm_string = "";
                                                if(!$vm_uuid) { $vm_uuid="N/A"; }
                                                $rdm_string="<td>$vm_name</td><td>$compat_mode</td><td>$vmhba</td><td>$disk_mode</td><td>$lun_uuid</td><td>$vm_uuid</td>";
                                                push @rdm_vms,$rdm_string;
                                        }
                                }
				if($device->isa('VirtualDisk')) { $numOfDisks += 1; }
                        }



                        print REPORT_OUTPUT "<td>",$numOfDisks,"</td>";
                        if (defined($vm->summary->config->numCpu)) {print REPORT_OUTPUT "<td>",$vm->summary->config->numCpu,"</td>"; }
                        else {print REPORT_OUTPUT "<td>UNKNOWN</td>"; }
                        if (defined($vm->summary->config->memorySizeMB)) {print REPORT_OUTPUT "<td>",prettyPrintData($vm->summary->config->memorySizeMB,'M'),"</td>"; }
                        else {print REPORT_OUTPUT "<td>UNKNOWN</td>"; }
                        my $isTemplate = $vm->config->template;
                        if (!$isTemplate) {
                                if (defined($vm->summary->quickStats->overallCpuUsage)) {print REPORT_OUTPUT "<td>",prettyPrintData($vm->summary->quickStats->overallCpuUsage,'MHZ'),"</td>"; }
                                else {print REPORT_OUTPUT "<td>UNKNOWN</td>"; }
                                if (defined($vm->summary->quickStats->guestMemoryUsage)) {print REPORT_OUTPUT "<td>",prettyPrintData($vm->summary->quickStats->guestMemoryUsage,'M'),"</td>"; }
                                else {print REPORT_OUTPUT "<td>UNKNOWN</td>"; }
                                if (defined($vm->summary->config->cpuReservation)) {print REPORT_OUTPUT "<td>",prettyPrintData($vm->summary->config->cpuReservation,'MHZ'),"</td>"; }
                                else {print REPORT_OUTPUT "<td>UNKNOWN</td>"; }
                                if (defined($vm->summary->config->memoryReservation)) {print REPORT_OUTPUT "<td>",prettyPrintData($vm->summary->config->memoryReservation,'M'),"</td>"; }
                                else {print REPORT_OUTPUT "<td>UNKNOWN</td>"; }
                        }
                        else {
                                print REPORT_OUTPUT "<td>N/A</td>";
                                print REPORT_OUTPUT "<td>N/A</td>";
                                print REPORT_OUTPUT "<td>N/A</td>";
                                print REPORT_OUTPUT "<td>N/A</td>";

                        }
                        if (defined($vm->summary->config->numEthernetCards)) {print REPORT_OUTPUT "<td>",$vm->summary->config->numEthernetCards,"</td>"; }
                        else {print REPORT_OUTPUT "<td>UNKNOWN</td>"; }
                        if (! $isTemplate) {
                                if (defined($vm->summary->guest->toolsStatus)) {print REPORT_OUTPUT "<td>",$vm->summary->guest->toolsStatus->val,"</td>"; }
                                else {print REPORT_OUTPUT "<td>UNKNOWN</td>"; }
				if (defined($vm->config->tools->syncTimeWithHost)) { print REPORT_OUTPUT "<td>",($vm->config->tools->syncTimeWithHost) ? "YES" : "NO","</td>"; }
				else {print REPORT_OUTPUT "<td>UNKNOWN</td>"; }
                                if (defined($vm->config->tools->toolsVersion)) {print REPORT_OUTPUT "<td>",$vm->config->tools->toolsVersion,"</td>"; }
                                else {print REPORT_OUTPUT "<td>UNKNOWN</td>"; }
                                if (defined($vm->config->tools->toolsUpgradePolicy)) {print REPORT_OUTPUT "<td>",$vm->config->tools-> toolsUpgradePolicy,"</td>"; }
                                else {print REPORT_OUTPUT "<td>UNKNOWN</td>"; }
                                print REPORT_OUTPUT "<td>",($vm->runtime->toolsInstallerMounted) ? "YES" : "NO" ,"</td>";
                                if (defined($vm->summary->guest->guestFullName)) {print REPORT_OUTPUT "<td>",$vm->summary->guest->guestFullName,"</td>"; }
                                else {print REPORT_OUTPUT "<td>UNKNOWN</td>"; }
                        }
                        else {
                                print REPORT_OUTPUT "<td>N/A</td>";
                                print REPORT_OUTPUT "<td>N/A</td>";
                                print REPORT_OUTPUT "<td>N/A</td>";
                                print REPORT_OUTPUT "<td>N/A</td>";
                                print REPORT_OUTPUT "<td>N/A</td>";
				print REPORT_OUTPUT "<td>N/A</td>";
                        }
                        print REPORT_OUTPUT "<td>",($isTemplate) ? "YES" : "NO" ,"</td>";
                        print REPORT_OUTPUT "</tr>\n";

			#retrieve vms w/NPIV
			my $nwwns = $vm->config->npivNodeWorldWideName;
			my $pwwns = $vm->config->npivPortWorldWideName;
			my $n_type = $vm->config->npivWorldWideNameType;
			if( ($nwwns) && ($seen_vm eq 1) ) {
				my $npiv_string = "";
				my $n_vm = $vm->config->name;
				$npiv_string .= "<td>$n_vm</td>";
				$npiv_string .= "<td>";
				foreach (@$nwwns) {
					my $nwwn = (Math::BigInt->new($_))->as_hex();
					$nwwn =~ s/^..//;
					$nwwn = join(':', unpack('A2' x 8, $nwwn));
					if($enable_demo_mode eq 1) {
						$npiv_string .= "XX:XX:XX:XX:XX:XX:XX:XX<br>";
					}
					else {
						$npiv_string .= "$nwwn<br>";
					}
				}
				$npiv_string .= "</td><td>";
				foreach (@$pwwns) {
					my $pwwn = (Math::BigInt->new($_))->as_hex();
					$pwwn =~ s/^..//;
                                        $pwwn = join(':', unpack('A2' x 8, $pwwn));
					if($enable_demo_mode eq 1) {
						$npiv_string .= "XX:XX:XX:XX:XX:XX:XX:XX<br>";
					}
					else {
						$npiv_string .= "$pwwn<br>";
					}
                                }
				if($n_type eq 'vc') { $n_type = "Virtual Center"; }
				elsif($n_type eq 'external') { $n_type = "External Source"; }
				elsif($n_type eq 'host') { $n_type = "ESX or ESXi"; }
				$npiv_string .= "</td><td>$n_type</td>";
				push @npiv_vms,$npiv_string;
			}

                        #retrieve vms w/snapshots
                        if(defined($vm->snapshot)) {
                                if($seen_vm eq 1) {
                                        print_tree ($vm->config->name,$vm->snapshot->currentSnapshot, $vm->snapshot->rootSnapshotList);
                                }
                        }

			#retrieve datastore summary from VM
                        my $vm_datastore_view = $vm->datastore;
                        foreach (@$vm_datastore_view) {
                                if($seen_vm eq 1) {
					my $ds = Vim::get_view(mo_ref => $_, properties => ['summary.name']);
					$vms_storage{$vm->config->name} = $ds->{'summary.name'};
                                }
                        }
			
                        #retrieve disk summary from VM
                        my $disks = $vm->guest->disk;
                        my $vm_name;
                        my $disk_string = "";
                        foreach my $disk (@$disks) {
                                if($seen_vm eq 1) {
                                        $vm_name = $vm->config->name;
                                        my $vm_disk_path = $disk->diskPath;
                                        my $vm_disk_free = prettyPrintData($disk->freeSpace,'B');
                                        my $vm_disk_cap = prettyPrintData($disk->capacity,'B');
                                        my $vm_perc_free = &restrict_num_decimal_digits((($disk->freeSpace / $disk->capacity) * 100),2);
					my $perc_string = getColor($vm_perc_free);
                                        $disk_string .= "<td><table border=1 width=100%><tr><td>$vm_disk_path</td><td>$vm_disk_free</td><td>$vm_disk_cap</td>$perc_string</tr></table></td>";
                                }
                        }
                        if (defined($vm_name)) {
                                $vms_disks{$vm_name} = $disk_string;
                        }

                        #retrieve network summary from VM
                        my $vm_nets = $vm->guest->net;
                        my $vm_conn_string = "";
                        my $vm_ip_string = "";
                        my $vm_mac_string = "";
                        my $vm_pg_string = "";

                        foreach my $vm_net (@$vm_nets) {
                                if($seen_vm eq 1) {
                                        $execute_flag = 1;
                                        my $net_conn = $vm_net->connected;
                                        if($net_conn eq '1') { $net_conn = "YES"; } else { $net_conn = "NO"; }
                                        $vm_conn_string .= $net_conn."<br>";
                                        my $ip_arr = $vm_net->ipAddress;
                                        foreach (@$ip_arr) {
						if($enable_demo_mode eq 1) {
                                                	$vm_ip_string .= "HIDE ME!<br>";
						}
						else {
							$vm_ip_string .= $_."<br>";
						}
                                        }
                                        my $net_mac = $vm_net->macAddress;
					my $net_pg = $vm_net->network;
                                        if($enable_demo_mode eq 1) {
                                                $net_mac .= "HIDE MY MAC!<br>";
						$vm_pg_string .= "HIDE MY PG!<br>";
                                        }
					else {
                                        	$vm_mac_string .= $net_mac."<br>";
						$vm_pg_string .= $net_pg."<br>";
					}
                                        if($vm_ip_string eq '') { $vm_ip_string="UNKNOWN<br>"; }
                                        if($vm_mac_string eq '') { $vm_mac_string="UNKNOWN<br>"; }
                                        if($vm_pg_string eq '') { $vm_pg_string="UNKNOWN<br>"; }
                                        if($vm_conn_string eq '') { $vm_conn_string="UNKNOWN<br>"; }
                                }
                        }
                        #could not retrieve network info (no VMware tools or not online)
                        if(!@$vm_nets) {
                                $vm_ip_string="UNKNOWN<br>";
                                $vm_mac_string="UNKNOWN<br>";
                                $vm_pg_string="UNKNOWN<br>";
                                $vm_conn_string="UNKNOWN<br>";
                        }
                        if($execute_flag eq 1) {
                                $net_vms{$vm->config->name} = "<td>".$vm_ip_string."</td><td>".$vm_mac_string."</td><td>".$vm_pg_string."</td><td>".$vm_conn_string."</td>";
                                $execute_flag = 0;
                        }
                        $seen_vm = 0;
                }
        }
        print REPORT_OUTPUT "</table>\n";
}

sub printHostDatastoreInfo {
	my ($local_hosts) = @_;
	###########################
        # PRINT DATASTORE SUMMARY
        ###########################
	push @jump_tags,"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href=\"#ESX/ESXi Datastore(s)-$cluster_count\">ESX/ESXi Datastore(s)</a><br>\n";
	print REPORT_OUTPUT "\n<a name=\"ESX/ESXi Datastore(s)-$cluster_count\"></a>\n";
        print REPORT_OUTPUT "<H3>ESX/ESXi Datastore(s):</H3>\n";
	print REPORT_OUTPUT "<table border=1><tr><td bgcolor=\"#CCCCCC\"><b>COLOR LEGEND</b></td><td bgcolor=\"yellow\"><b>YELLOW < $yellow_warn %</b></td><td bgcolor=\"orange\"><b>ORANGE < $orange_warn %</b></td><td bgcolor=\"red\"><b>RED < $red_warn %</b></td></tr></table>\n";
        print REPORT_OUTPUT "<table border=1>\n";
        print REPORT_OUTPUT "<tr><th>DATASTORE</th><th>CAPACITY</th><th>CONSUMED</th><th>FREE</th><th>% FREE</th><th>DS TYPE</th><th>HOST(s) NOT ACCESSIBLE TO DATASTORE</tr>\n";
        my @datastores_seen = ();
	my %datastores = ();
	my %datastore_row_info = ();
	my $ctr = 0;
        foreach my $host (@$local_hosts) {
                my $ds_views = Vim::get_views (mo_ref_array => $host->datastore);
                foreach my $ds (sort {$a->info->name cmp $b->info->name} @$ds_views) {
			my $ds_row = "";
				if($ds->summary->accessible) {
				#capture unique datastores seen in cluster
                                if (!grep {$_ eq $ds->info->name} @datastores_seen) {
                                        push @datastores_seen,$ds->info->name;
                                        my $perc_free;
					my $perc_string = "";
                                        my $ds_used;
                                        my $ds_free;
					my $ds_cap;			
                                        if ( ($ds->summary->freeSpace gt 0) || ($ds->summary->capacity gt 0) ) {
						$ds_cap = &restrict_num_decimal_digits($ds->summary->capacity/1024/1000,2);
						$ds_used = prettyPrintData(($ds->summary->capacity - $ds->summary->freeSpace),'B');
						$ds_free = &restrict_num_decimal_digits(($ds->summary->freeSpace/1024/1000),2);
						$perc_free = &restrict_num_decimal_digits(( 100 * $ds_free / $ds_cap),2);
                                        	$perc_string = getColor($perc_free);
					}
                                        else {
                                                $perc_free = "UNKNOWN";
                                                $ds_used = "UNKNOWN";
                                                $ds_free = "UNKNOWN";
                                        }
					$ds_row = "</td><td>".(prettyPrintData($ds->summary->capacity,'B'))."</td><td>".$ds_used."</td><td>".prettyPrintData($ds->summary->freeSpace,'B')."</td>$perc_string<td>".$ds->summary->type."</td>";
					
					$datastore_row_info{$ds->info->name} = $ds_row;
					
					#capture VM dir contents w/delta files
					my $browser = Vim::get_view (mo_ref => $ds->browser);
					my $ds_path = "[" . $ds->info->name . "]";

					my $file_query = FileQueryFlags->new(fileSize => 1,fileType => 0,modification => 1, fileOwner => 0);

					my $searchSpec = HostDatastoreBrowserSearchSpec->new(details => $file_query,matchPattern => ["*.vmsn", "*-delta.vmdk"]);
					my $search_res = $browser->SearchDatastoreSubFolders(datastorePath => $ds_path,searchSpec => $searchSpec);

					if ($search_res) {
						foreach my $result (@$search_res) {
							my $files = $result->file;
							if ($files) {
	        						foreach my $file (@$files) {
									if($file->path =~ /-delta.vmdk/ ) {
										my ($vm_snapshot_date,$vm_snapshot_time) = split('T',$file->modification);
										#my $todays_date =`date +\%Y-\%m-\%d`;
										my $todays_date = giveMeDate('YMD');
										chomp($todays_date);
										my $diff = days_between($vm_snapshot_date, $todays_date);
										my $snap_time = $vm_snapshot_date." ".$vm_snapshot_time;
										setSnapColor($diff,$result->folderPath,$file->path,$file->fileSize,$snap_time);	
									}
	        						}
							}
						}
					}
                                }
				$datastores{$ds->info->name} .= $host->summary->config->name. "_" . $ctr++ .",";
			}
                }
        }
	#logic to check which hosts can see all datastores
        while ( my ($ds, $value) = each(%datastores) ) {
                my @pairs = split(',',$value);
                my $pair_count = @pairs;
                my @hosts_to_datastores = ();
                for (my $x=0;$x < $pair_count;$x++) {
                        (my $hostname,my $count) = split('_',$pairs[$x],2);
                        push @hosts_to_datastores, $hostname;
                }
                #logic to figure out which hosts can not see this datastore
                my @intersection = ();
                my @difference = ();
                my %count = ();
                foreach my $element (@hosts_to_datastores, @hosts_seen) { $count{$element}++ }
                foreach my $element (keys %count) {
                        push @{ $count{$element} > 1 ? \@intersection : \@difference }, $element;
                }

                my $print_string = "";
                if(@difference) {
                        foreach (@difference) {
                                $print_string .= $_." ";
                        }
                }
                if($print_string eq '') {
                        $print_string = "<td bgcolor=\"#66FF99\">Accessible by all hosts in this cluster</td>";
                } else {
                        if($enable_demo_mode eq 1) {
                                $print_string .= "<td bgcolor=\"#FF6666\">HIDE ME!</td>";
                        }
                        else {
                                $print_string = "<td bgcolor=\"#FF6666\">".$print_string."</td>";
                        }
                }
                $datastore_row_info{$ds} .= $print_string;
                @hosts_to_datastores = ();
        }

	#final print of datastore summary
	for my $datastore ( sort keys %datastore_row_info ) {
		my $value = $datastore_row_info{$datastore};
		print REPORT_OUTPUT "<tr><td>",$datastore,"</td>",$value,"</tr>\n";
	}
        print REPORT_OUTPUT "</table>\n";
}

#http://www.perlmonks.org/?node_id=17057
sub days_between {
        my ($start, $end) = @_;
        my ($y1, $m1, $d1) = split ("-", $start);
        my ($y2, $m2, $d2) = split ("-", $end);
        my $diff = mktime(0,0,0, $d2-1, $m2-1, $y2 - 1900) -  mktime(0,0,0, $d1-1, $m1-1, $y1 - 1900);
        return $diff / (60*60*24);
}

sub printHostLun {
	my ($local_hosts) = @_;
	my %lun_row_info = ();
	my %luns = ();
        foreach my $host (@$local_hosts) {
		my $luns = $host->config->storageDevice->scsiLun;
		foreach (sort {$a->canonicalName cmp $b->canonicalName} @$luns) {
			my $lun_row = "";
			if($_->isa('HostScsiDisk')) {
				$luns{$_->uuid} .= $host->summary->config->name . "_" . $_->canonicalName . "," ;
				$lun_row .= "<td>".$_->canonicalName."</td>";
				if($_->queueDepth) { $lun_row .= "<td>".$_->queueDepth."</td"; }
                                else { $lun_row .= "<td>N/A</td>"; }
				my $state_string = "";
				my $states = $_->operationalState;
				foreach (@$states) {
					$state_string .= $_." ";
				}
				$lun_row .= "<td>".$state_string."</td><td>".$_->vendor."</td>";
				$lun_row_info{$_->uuid} = $lun_row;
			}
		}
	}
	
	#logic to check which hosts can see all luns
	while ( my ($uuid, $value) = each(%luns) ) {
		my @pairs = split(',',$value);
    		my $pair_count = @pairs;
		my @hosts_to_luns = ();
    		for (my $x=0;$x < $pair_count;$x++) {
			(my $hostname,my $vmhba) = split('_',$pairs[$x],2);
			push @hosts_to_luns, $hostname;
		}
		#logic to figure out which hosts can not see this datastore
                my @intersection = ();
                my @difference = ();
                my %count = ();
                foreach my $element (@hosts_to_luns, @hosts_seen) { $count{$element}++ }
                foreach my $element (keys %count) {
                	push @{ $count{$element} > 1 ? \@intersection : \@difference }, $element;
                }

		my $print_string = "";
		if(@difference) {
			foreach (@difference) {
				$print_string .= $_." ";
			}
		}
		if($print_string eq '') {
			$print_string = "<td bgcolor=\"#66FF99\">Accessible by all hosts in this cluster</td>";
		} else {
			if($enable_demo_mode eq 1) {
                                $print_string .= "<td bgcolor=\"#FF6666\">HIDE ME!</td>";
                        }
			else {
				$print_string = "<td bgcolor=\"#FF6666\">".$print_string."</td>";
			}
		}
		$lun_row_info{$uuid} .= $print_string;
		@hosts_to_luns = ();
	}

	###########################
        # PRINT LUN SUMMARY
        ###########################
        push @jump_tags,"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href=\"#ESX/ESXi LUN(s)-$cluster_count\">ESX/ESXi LUN(s)</a><br>\n";
        print REPORT_OUTPUT "\n<a name=\"ESX/ESXi LUN(s)-$cluster_count\"></a>\n";
        print REPORT_OUTPUT "<H3>ESX/ESXi LUN(s):</H3>\n";
        print REPORT_OUTPUT "<table border=1>\n";
        print REPORT_OUTPUT "<tr><th>UUID</th><th>LUN</th><th>QUEUE DEPTH</th><th>STATUS</th><th>VENDOR</th><th>HOST(s) NOT ACCESSIBLE TO LUN</tr>\n";
	for my $lun ( sort keys %lun_row_info ) {
                my $value = $lun_row_info{$lun};
                print REPORT_OUTPUT "<tr><td>",$lun,"</td>",$value,"</tr>\n";
        }
	print REPORT_OUTPUT "</table>\n";
}

sub printMultipathing {
	my ($host) = @_;
	my $hostName;
	if($enable_demo_mode eq 1) { $hostName = $randomHostName;
        } else { $hostName = $host->summary->config->name; }

	###########################
        # PRINT MULTIPATH SUMMARY
        ###########################
	if($opt_type eq 'detail-hosts') {
        push @jump_tags,"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href=\"#$hostName Disk Multipathing Info\">Disk Multipathing Info</a><br>\n";
	print REPORT_OUTPUT "\n<a name=\"$hostName Disk Multipathing Info\"></a>\n";
	print REPORT_OUTPUT "<H3>Disk Multipathing Info:</H3>\n";
	} else { push @jump_tags,"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href=\"#ESX/ESXi Disk Multipathing Info-$cluster_count\">ESX/ESXi Disk Multipathing Info</a><br>\n"; 
        print REPORT_OUTPUT "\n<a name=\"ESX/ESXi Disk Multipathing Info-$cluster_count\"></a>\n"; 
        print REPORT_OUTPUT "<H3>ESX/ESXi Disk Multipathing Info:</H3>\n"; }
        print REPORT_OUTPUT "<table border=1>\n";
   		my $ss = Vim::get_view (mo_ref => $host->configManager->storageSystem);

		my $verbose;
   		my $luns = $ss->storageDeviceInfo->scsiLun;
   		my $hbas = $ss->storageDeviceInfo->hostBusAdapter;
   		my $mpLuns = $ss->storageDeviceInfo->multipathInfo->lun;
   		foreach my $mpLun (@$mpLuns) {
      			my $paths = $mpLun->path;
      			my $numPaths = scalar(@$paths);
      			my $lun = find_by_key($luns, $mpLun->lun);

      			my $pol = $mpLun->policy;
      			my $polPrefer;
      			if (defined($pol) && defined($pol->{prefer})) {
         			$polPrefer = $pol->prefer;
      			}

      			my $cap = $lun->{capacity};
      			my $deviceUuidPath = defined($lun->{uuid}) ? ("vml." . $lun->uuid) : "";
			print REPORT_OUTPUT "<table border=1>\n";
			print REPORT_OUTPUT "<tr><th>",(defined($lun->{lunType}) ? $lun->lunType : "")," ",(defined($lun->{canonicalName}) ? $lun->canonicalName : ""),($verbose ? " $deviceUuidPath" : "")," ",(defined($cap) ? " ( " . int($cap->block * $cap->blockSize / (1024*1024)) . " MB )" : " ( 0 MB )")," ==  # of Paths: ",$numPaths," Policy: ",((defined($pol) && defined($pol->{policy})) ? $pol->policy : ""),"</th></tr>\n";
			
      			foreach my $path (@$paths) {
         			my $hba = find_by_key($hbas, $path->adapter);
	         		my $isFC = $hba->isa("HostFibreChannelHba");
        	 		my $state = ($path->{pathState} ?
                	       (($path->pathState eq "active") ? "On active" : $path->pathState) : "");

         			my $pciString = get_pci_string($hba);
				if($enable_demo_mode eq 1) {
					print REPORT_OUTPUT "<tr><td>",($isFC ? "FC" : "Local")," ",$pciString," ","HIDE MY NWWN <-> HIDE MY PWWN"," ",$path->name," ",$state," ",((defined($polPrefer) && ($path->name eq $polPrefer)) ? "preferred" : ""),"</td></tr>\n";
				} else {	
					print REPORT_OUTPUT "<tr><td>",($isFC ? "FC" : "Local")," ",$pciString," ",($isFC ? $hba->nodeWorldWideName . "<->" . $hba->portWorldWideName : "")," ",$path->name," ",$state," ",((defined($polPrefer) && ($path->name eq $polPrefer)) ? "preferred" : ""),"</td></tr>\n"; 
				}
  			}
			print REPORT_OUTPUT "</table><br>\n";
   		} 
	print REPORT_OUTPUT "</table>\n";
}

sub get_pci_string {
   my $hba = shift;
   my $pciString = defined($hba) ? $hba->pci : "";
   # defect 173631
   if ($pciString =~ /([a-fA-F0-9]+):([a-fA-F0-9]+)\.([a-fA-F0-9]+)$/) {
      $pciString = hexstr_to_int($1)
                   . ":" . hexstr_to_int($2)
                   . "." . hexstr_to_int($3);
   }
   return $pciString
}

sub hexstr_to_int {
    my ($hexstr) = @_;
    die "Invalid hex string: $hexstr"
    if $hexstr !~ /^[0-9A-Fa-f]{1,8}$/;
    my $num = hex($hexstr);
    return $num >> 31 ? $num - 2 ** 32 : $num;
}

sub find_by_key {
   my ($list, $key) = @_;

   foreach my $item (@$list) {
      if ($key eq $item->key) {
         return $item;
      }
   }

   return undef;
}


sub printHostPortgroup {
	my ($local_hosts) = @_;
	my @hosts_to_portgroups = ();
	foreach my $host (@$local_hosts) {
                my $portgroup_views = Vim::get_views (mo_ref_array => $host->network);
                foreach my $portgroup (sort {$a->summary->name cmp $b->summary->name} @$portgroup_views) {
			my $pg_row = "";
			if($portgroup->summary->accessible) {
				my $host_mounts = $portgroup->host;
				foreach (@$host_mounts) {
					my $host_on_portgroup = Vim::get_view (mo_ref => $_, properties => ['name']);
					push @hosts_to_portgroups,$host_on_portgroup->name;
				}
			
				#logic to figure out which hosts can not see this portgroup
				my @intersection = ();
                                my @difference = ();
                                my %count = ();
                                foreach my $element (@hosts_to_portgroups, @hosts_seen) { $count{$element}++ }
                                foreach my $element (keys %count) {
                                	push @{ $count{$element} > 1 ? \@intersection : \@difference }, $element;
                                }
				if(@difference) {
                                	my $hosts_not_accessible = "";
                                        foreach (@difference) {
                                        	$hosts_not_accessible .= $_." ";
                                        }
					if($enable_demo_mode eq 1) {
                                        	$pg_row .= "<td bgcolor=\"#FF6666\">HIDE ME!</td>";
					} else {
						$pg_row .= "<td bgcolor=\"#FF6666\">$hosts_not_accessible</td>";
					}
                                }
                                else {
                                	$pg_row .= "<td bgcolor=\"#66FF99\">Accessible by all hosts in this cluster</td>";
                                }
				$portgroup_row_info{$portgroup->name} = $pg_row;
				@hosts_to_portgroups = ();
			}
		}
	}

	#final print of portgroup summary
	###########################
        # PRINT PORTGROUP SUMMARY
        ###########################
        push @jump_tags,"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href=\"#ESX/ESXi Portroup(s)-$cluster_count\">ESX/ESXi Portroup(s)</a><br>\n";
        print REPORT_OUTPUT "\n<a name=\"ESX/ESXi Portroup(s)-$cluster_count\"></a>\n";
        print REPORT_OUTPUT "</table>\n";
        print REPORT_OUTPUT "<H3>ESX/ESXi Portroup(s):</H3>\n";
        print REPORT_OUTPUT "<table border=1>\n";
        print REPORT_OUTPUT "<tr><th>PORTGROUP</th><th>HOST(s) NOT ACCESSIBLE TO PORTGROUP</th></tr>\n";
        for my $portgroup ( sort keys %portgroup_row_info ) {
                my $value = $portgroup_row_info{$portgroup};
		if($enable_demo_mode eq 1) {
			$portgroup = "HIDE MY PG!";
		}
                print REPORT_OUTPUT "<tr><td>",$portgroup,"</td>",$value,"</tr>\n";
        }
        print REPORT_OUTPUT "</table>\n";
}

sub clusterPG {
	my ($cluster) = @_;
	my @hosts_in_cluster = ();
	my @hosts_in_portgroup = ();
	my $pg_row = "";
	my $pg_name;
	
	my $hic = Vim::get_views(mo_ref_array => $cluster->host, properties => ['name']);
	foreach(@$hic) {
		push @hosts_in_cluster,$_->{'name'};	
	}

	my $pg = Vim::get_views(mo_ref_array => $cluster->network);
	foreach(@$pg) {
		my $hosts = Vim::get_views(mo_ref_array => $_->host, properties => ['name']);
		$pg_name = $_->name;
		foreach(@$hosts) {
			push @hosts_in_portgroup,$_->{'name'};
		}

	        #logic to figure out which hosts can not see this portgroup
        	my @intersection = ();
	        my @difference = ();
	        my %count = ();
	        foreach my $element (@hosts_in_portgroup, @hosts_in_cluster) { $count{$element}++ }
	       	foreach my $element (keys %count) {
        		push @{ $count{$element} > 1 ? \@intersection : \@difference }, $element;
	        }

                my @hosts_not_prop_configured = ();
                my @difference_2 = ();
                %count = ();
                foreach my $element (@difference, @hosts_in_cluster) { $count{$element}++ }
                foreach my $element (keys %count) {
                        push @{ $count{$element} > 1 ? \@hosts_not_prop_configured : \@difference_2 }, $element;
                }

	        if(@hosts_not_prop_configured) {
	        	my $hosts_not_accessible = "";
        	        foreach (@hosts_not_prop_configured) {
        		        $hosts_not_accessible .= $_." ";
        		}
        		if($enable_demo_mode eq 1) {
        			$pg_row .= "<td bgcolor=\"#FF6666\">HIDE ME!</td>";
      			} else {
        			$pg_row .= "<td bgcolor=\"#FF6666\">$hosts_not_accessible</td>";
        		}
        	} else {
        		$pg_row .= "<td bgcolor=\"#66FF99\">Accessible by all hosts in this cluster</td>";
        	}
       		$portgroup_row_info{$pg_name} = $pg_row;
		$pg_row = "";
		@hosts_in_portgroup = ();
	}
	@hosts_in_cluster = ();
}

sub printPG {
	#final print of portgroup summary
        ###########################
        # PRINT PORTGROUP SUMMARY
        ###########################
        push @jump_tags,"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href=\"#ESX/ESXi Portroup(s)-$cluster_count\">ESX/ESXi Portroup(s)</a><br>\n";
        print REPORT_OUTPUT "\n<a name=\"ESX/ESXi Portroup(s)-$cluster_count\"></a>\n";
        print REPORT_OUTPUT "</table>\n";
        print REPORT_OUTPUT "<H3>ESX/ESXi Portroup(s):</H3>\n";
        print REPORT_OUTPUT "<table border=1>\n";
        print REPORT_OUTPUT "<tr><th>PORTGROUP</th><th>HOST(s) NOT ACCESSIBLE TO PORTGROUP</th></tr>\n";
        for my $portgroup ( sort keys %portgroup_row_info ) {
                my $value = $portgroup_row_info{$portgroup};
                if($enable_demo_mode eq 1) {
                        $portgroup = "HIDE MY PG!";
                }
                print REPORT_OUTPUT "<tr><td>",$portgroup,"</td>",$value,"</tr>\n";
        }
        print REPORT_OUTPUT "</table>\n";
	%portgroup_row_info = ();
}

sub printHostHardwareInfo {
	my ($local_hosts) = @_;

	###########################
        # PRINT HOST HARDWARE
        ###########################
	push @jump_tags,"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href=\"#ESX/ESXi hardware configuration-$cluster_count\">ESX/ESXi hardware configuration</a><br>\n";
	print REPORT_OUTPUT "<br>\n";
	print REPORT_OUTPUT "\n<a name=\"ESX/ESXi hardware configuration-$cluster_count\"></a>\n";
        print REPORT_OUTPUT "<table border=1>\n";
        print REPORT_OUTPUT "<tr><th>HOSTNAME</th><th>VENDOR</th><th>ADDITIONAL VENDOR INFO</th><th>CPU INFO</th><th>HT AVAILABLE/ENABLED</th><th>CPU SPEED</th><th>CPU USAGE</th><th>CPU PACKAGE(s)</th><th>CPU CORE(s)</th><th>CPU THREAD(s)</th><th>MEMORY</th><th>MEMORY USAGE</th><th>NIC(s)</th><th>HBA(s)</th></tr>\n";
        print REPORT_OUTPUT "<H3>ESX/ESXi hardware configuration:</H3>\n";
        foreach my $local_host (sort {$a->summary->config->name cmp $b->summary->config->name} @$local_hosts) {
                print REPORT_OUTPUT "<tr>";
		if($enable_demo_mode eq 1) {
                	print REPORT_OUTPUT "<td>HIDE ME!</td>";
               	}
                else {
                	print REPORT_OUTPUT "<td>",$local_host->summary->config->name,"</td>";
		}
                print REPORT_OUTPUT "<td>",$local_host->summary->hardware->vendor,"</td>";
		my $additional_vendor_info = "";
		if($local_host->summary->hardware->otherIdentifyingInfo) {
			my $add_info = $local_host->summary->hardware->otherIdentifyingInfo;
			foreach (@$add_info) {
				$additional_vendor_info .= $_->identifierType->key.": ".$_->identifierValue." ";
			}
			if($additional_vendor_info eq '') {
				$additional_vendor_info = "UNKNOWN";
			}
		}
		print REPORT_OUTPUT "<td>",$additional_vendor_info,"</td>";
                print REPORT_OUTPUT "<td>",$local_host->summary->hardware->cpuModel,"</td>";
                print REPORT_OUTPUT "<td>",($local_host->config->hyperThread->available) ? "YES" : "NO"," / ";
		print REPORT_OUTPUT ($local_host->config->hyperThread->active) ? "YES" : "NO","</td>";
                print REPORT_OUTPUT "<td>",prettyPrintData($local_host->summary->hardware->numCpuCores*$local_host->summary->hardware->cpuMhz,'MHZ'),"</td>";
                print REPORT_OUTPUT "<td>",prettyPrintData($local_host->summary->quickStats->overallCpuUsage,'MHZ'),"</td>";
                print REPORT_OUTPUT "<td>",$local_host->summary->hardware->numCpuPkgs,"</td>";
                print REPORT_OUTPUT "<td>",$local_host->summary->hardware->numCpuCores,"</td>";
                print REPORT_OUTPUT "<td>",$local_host->summary->hardware->numCpuThreads,"</td>";
                print REPORT_OUTPUT "<td>",prettyPrintData($local_host->summary->hardware->memorySize,'B'),"</td>";
                print REPORT_OUTPUT "<td>",prettyPrintData($local_host->summary->quickStats->overallMemoryUsage,'M'),"</td>";
                print REPORT_OUTPUT "<td>",$local_host->summary->hardware->numNics,"</td>";
                print REPORT_OUTPUT "<td>",$local_host->summary->hardware->numHBAs,"</td>";
                print REPORT_OUTPUT "</tr>\n";

		#capture unique hosts for later use
	        push @hosts_seen,$local_host->summary->config->name;

		#get health
		getHealthInfo($local_host);

                #get nic
		getNICInfo($local_host);

                #get hba
                getHBAInfo($local_host);

        }
	print REPORT_OUTPUT "</table>\n";

	###########################
        # PRINT HEALTH STATUS
	###########################
        printHealth();

	###########################
        # PRINT NIC INFO
        ###########################
        printNIC();

        ###########################
        # PRINT HBA INFO
        ###########################
        printHBA();

        ###########################
        # PRINT HOST STATE
        ###########################
        print REPORT_OUTPUT "\n</table>\n";
        print REPORT_OUTPUT "<H3>ESX/ESXi state:</H3>\n";
        print REPORT_OUTPUT "<table border=1>\n";
        print REPORT_OUTPUT "<tr><th>HOSTNAME</th><th>OVERALL STATUS</th><th>POWER STATE</th><th>CONNECTION STATE</th><th>MAINTENANCE MODE</th><th>VMOTION ENABLED</th><th>VERSION</th></tr>\n";
        foreach my $local_host (sort {$a->summary->config->name cmp $b->summary->config->name} @$local_hosts) {
                print REPORT_OUTPUT "<tr>";
		if($enable_demo_mode eq 1) {
                	print REPORT_OUTPUT "<td>HIDE ME!</td>";
                }
		else {
			print REPORT_OUTPUT "<td>",$local_host->summary->config->name,"</td>";
		}
                my $host_health = $local_host->overallStatus->val;
                if ($host_health eq 'green') { print REPORT_OUTPUT "<td bgcolor=\"green\">HOST is OK</td>"; }
                elsif ($host_health eq 'red') { print REPORT_OUTPUT "<td bgcolor=\"red\">HOST has a problem</td>"; }
                elsif ($host_health eq 'yellow') { print REPORT_OUTPUT "<td bgcolor=\"yellow\">HOST might have a problem</td>"; }
                else { print REPORT_OUTPUT "<td bgcolor=\"gray\">UNKNOWN</td>"; }
                print REPORT_OUTPUT "<td>",$local_host->runtime->powerState->val,"</td>";
                print REPORT_OUTPUT "<td>",$local_host->runtime->connectionState->val,"</td>";
                print REPORT_OUTPUT "<td>",($local_host->summary->runtime->inMaintenanceMode) ? "YES" : "NO" ,"</td>";
                print REPORT_OUTPUT "<td>",($local_host->summary->config->vmotionEnabled) ? "YES" : "NO" ,"</td>";
                print REPORT_OUTPUT "<td>",${$local_host->summary->config->product}{'fullName'},"</td>";
                print REPORT_OUTPUT "</tr>\n";
        }
        print REPORT_OUTPUT "</table>\n";

	###########################
        # PRINT HOST CONFIG
        ###########################
	if($opt_type ne 'detail-hosts') {
        	print REPORT_OUTPUT "</table>\n";
		push @jump_tags,"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href=\"#ESX/ESXi Configurations-$cluster_count\">ESX/ESXi Configurations</a><br>\n";
       		print REPORT_OUTPUT "\n<a name=\"ESX/ESXi Configurations-$cluster_count\"></a>\n";
		print REPORT_OUTPUT "<H3>ESX/ESXi Configurations:</H3>\n";
        	print REPORT_OUTPUT "<table border=1>\n";
        	print REPORT_OUTPUT "<tr><th>HOSTNAME</th><th>UUID</th><th>SERVICE CONSOLE MEMORY</th><th>AUTOSTART MANAGER</th><th>LVM.EnableResignature</th><th>LVM.DisallowSnapshotLun</th><th>Disk.UseDeviceReset</th><th>Disk.UseLunReset</th><th>Disk.SchedNumReqOutstanding</th><th>NFS.LockDisable</th></tr>\n";
	}
	foreach my $local_host (sort {$a->summary->config->name cmp $b->summary->config->name} @$local_hosts) {
		if($enable_demo_mode eq 1) { $randomHostName = "ESX-DEV-HOST-".int(rand(100)).".primp-industries.com"; }
		if($opt_type eq 'detail-hosts') {
			my $hostName;
			if($enable_demo_mode eq 1) { $hostName = $randomHostName;
			} else { $hostName = $local_host->summary->config->name; }
			print REPORT_OUTPUT "</table>\n";
                	push @jump_tags,"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href=\"#$hostName configurations-$cluster_count\">$hostName configurations</a><br>\n";
                	print REPORT_OUTPUT "\n<a name=\"$hostName configurations-$cluster_count\"></a>\n";
			print REPORT_OUTPUT "<H3>$hostName configurations:</H3>\n";
                	print REPORT_OUTPUT "<table border=1>\n";
                	print REPORT_OUTPUT "<tr><th>HOSTNAME</th><th>UUID</th><th>SERVICE CONSOLE MEMORY</th><th>AUTOSTART MANAGER</th><th>LVM.EnableResignature</th><th>LVM.DisallowSnapshotLun</th><th>Disk.UseDeviceReset</th><th>Disk.UseLunReset</th><th>Disk.SchedNumReqOutstanding</th><th>NFS.LockDisable</th></tr>\n";
		}
		print REPORT_OUTPUT "<tr>";
		if($enable_demo_mode eq 1) {
                	print REPORT_OUTPUT "<td>HIDE ME!</td>";
                }
		else {        
                	print REPORT_OUTPUT "<td>",$local_host->summary->config->name,"</td>";
		}
		print REPORT_OUTPUT "<td>",$local_host->summary->hardware->uuid,"</td>";
		if(defined($local_host->config->consoleReservation)) {
			print REPORT_OUTPUT "<td>",prettyPrintData($local_host->config->consoleReservation->serviceConsoleReserved,'B'),"</td>";
		}
		else {
			print REPORT_OUTPUT "<td>UNKNOWN</td>";
		}
        	print REPORT_OUTPUT "<td>",($local_host->config->autoStart->defaults->enabled) ? "YES" : "NO","</td>";

		#advconfigs
		my $advconfigs = Vim::get_view (mo_ref => $local_host->configManager->advancedOption);
		my $options_ref = $advconfigs->setting;
		my $lvm_er = "UNKNOWN";
		my $lvm_ds = "UNKNOWN";
		my $d_udr = "UNKNOWN";
		my $d_ulr = "UNKNOWN";
		my $d_snro = "UNKNOWN";
		my $n_ld = "UNKNOWN";

		foreach my $option (@$options_ref) {
			my $key = $option->key;
			my $value = $option->value;

			if($key eq 'LVM.EnableResignature') {$lvm_er = $value; }
			if($key eq 'LVM.DisallowSnapshotLun') { $lvm_ds = $value; }
			if($key eq 'Disk.UseDeviceReset') { $d_udr = $value; }
			if($key eq 'Disk.UseLunReset') { $d_ulr = $value; }
			if($key eq 'Disk.SchedNumReqOutstanding') { $d_snro = $value; }
			if($key eq 'NFS.LockDisable') { $n_ld= $value; } 
		}

		print REPORT_OUTPUT "<td>",$lvm_er,"</td><td>",$lvm_ds,"</td><td>",$d_udr,"</td><td>",$d_ulr,"</td><td>",$d_snro,"</td><td>",$n_ld,"</td>";
		if($opt_type eq 'detail-hosts') {
                	print REPORT_OUTPUT "</tr>\n";
        	        print REPORT_OUTPUT "</table>\n";
			printDetailHostConfigurations($local_host);
			printLimitedVMInfo($local_host);
	        }
		elsif($opt_type eq 'host') {
			printDetailHostConfigurations($local_host);
		}
	}
	if($opt_type ne 'detail-hosts') {
		print REPORT_OUTPUT "</tr>\n";
		print REPORT_OUTPUT "</table>\n";
	}
}

sub printDetailHostConfigurations {
	my ($host) = @_;
	print REPORT_OUTPUT "<table border=1><br>\n";

		## SERVICE CONSOLE / VMOTION ##
		if ($host->summary->config->vmotionEnabled) {
			print REPORT_OUTPUT "<tr><th>VMOTION ENABLED </th><td>YES</td></tr>\n";
			if($enable_demo_mode eq 1) {
				print REPORT_OUTPUT "<tr><th>IP ADDRESS </th><td>X.X.X.X</td></tr>\n";
				print REPORT_OUTPUT "<tr><th>NETMASK </th><td>X.X.X.X</td></tr>\n";
			} else {
				print REPORT_OUTPUT "<tr><th>IP ADDRESS </th><td>",$host->config->vmotion->ipConfig->ipAddress," => ",$host->summary->config->name,"</td></tr>\n";
				print REPORT_OUTPUT "<tr><th>NETMASK </th><td>",$host->config->vmotion->ipConfig->subnetMask,"</td></tr>\n";
			}
		}

		## GATEWAY ##
		my $network_system;
		eval { $network_system = Vim::get_view(mo_ref => $host->configManager->networkSystem); };
		if(!$@) {
			if($enable_demo_mode eq 1) {
				print REPORT_OUTPUT "<tr><th>GATEWAY </th><td>X.X.X.X</td></tr>\n";
			} else {
				if($network_system->consoleIpRouteConfig->defaultGateway) {
					print REPORT_OUTPUT "<tr><th>GATEWAY </th><td>",$network_system->consoleIpRouteConfig->defaultGateway,"</td></tr>\n";
				} else { print REPORT_OUTPUT "<tr><th>GATEWAY </th><td>0.0.0.0</td></tr>\n"; }
				if($network_system->ipRouteConfig->defaultGateway) {
					print REPORT_OUTPUT "<tr><th>VMKERNEL GATEWAY </th><td>",$network_system->ipRouteConfig->defaultGateway,"</td></tr>\n";
				} else { print REPORT_OUTPUT "<tr><th>VMKERNEL GATEEWAY </th><td>0.0.0.0</td></tr>\n"; }
			}
		}
		
		## SOFTWARE iSCSI ##
		print REPORT_OUTPUT "<tr><th>SOFTWAE iSCSI ENABLED</th><td>",($host->config->storageDevice->softwareInternetScsiEnabled ? "YES" : "NO"),"</td></tr>\n";

		## DNS ##
		my $s_domains = $host->config->network->dnsConfig->searchDomain;
		my $s_string = "";
		foreach(@$s_domains) {
			$s_string .= "search ".$_."<br>";
		}
		my $dns_add = $host->config->network->dnsConfig->address;
		my $dns_string = "";
		foreach(@$dns_add) {
			$dns_string .= "nameserver ".$_."<br>";
		}
		if($enable_demo_mode eq 1) {	
			print REPORT_OUTPUT "<tr><th>DNS</th><td>domain X.domain.com<br>search Y.domain.com<br>nameserver Z.domain.com</td></tr>\n";
		} else {
			print REPORT_OUTPUT "<tr><th>DNS</th><td>","domain ", $host->config->network->dnsConfig->domainName,"<br>",$s_string,$dns_string,"</td></tr>\n";
		}

		## UPTIME ##
		my ($host_date,$host_time) = split('T',$host->runtime->bootTime);
                my $todays_date = giveMeDate('YMD');
                chomp($todays_date);
                my $up_time = days_between($host_date, $todays_date);
		print REPORT_OUTPUT "<tr><th>UPTIME</th><td>",$up_time," Days - ",$host->runtime->bootTime,"</td></tr>\n";

		## OFFLOAD CAPABILITIES ##
		my $offload_string = "";
		$offload_string .= "<tr><td>".($host->config->offloadCapabilities->csumOffload ? "YES" : "NO")."</td><td>".($host->config->offloadCapabilities->tcpSegmentation ? "YES" : "NO")."</td><td>".($host->config->offloadCapabilities->zeroCopyXmit ? "YES" : "NO")."</td></tr>";
		print REPORT_OUTPUT "<tr><th>OFFLOAD CAPABILITIES</th><td><table border=1 width=100%><tr><th>CHECKSUM</th><th>TCP SEGMENTATION</th><th>ZERO COPY TRANSMIT</th></tr>",$offload_string,"</table></td></tr>\n";

		## DIAGONISTIC PARITION ##
                if($host->config->activeDiagnosticPartition) {
			my $diag_string = "";
			$diag_string .= "<tr><td>".$host->config->activeDiagnosticPartition->diagnosticType."</td><td>".$host->config->activeDiagnosticPartition->id->diskName.$host->config->activeDiagnosticPartition->id->partition."</td><td>".$host->config->activeDiagnosticPartition->storageType."</td></tr>";
			print REPORT_OUTPUT "<tr><th>DIAGNOSTIC PARTITION</th><td><table border=1 width=100%><tr><th>TYPE</th><th>PARITION</th><th>STORAGE TYPE</th></tr>",$diag_string,"</table></td></tr>\n";
                }

		## SERVICES ##
		my $services = $host->config->service->service;
		my $service_string = "";
		foreach(@$services) {
			$service_string .= "<tr><td>".$_->label."</td><td>".$_->policy."</td><td>".(($_->running) ? "YES" : "NO")."</td></tr>";
		}
		print REPORT_OUTPUT "<tr><th>SERVICE(s)</th><td><table border=1 width=100%><tr><th>NAME</th><th>POLICY TYPE</th><th>RUNNING</th></tr>",$service_string,"</table></td></tr>\n";

		## NTP ##
                if($host->config->dateTimeInfo) {
                        my $ntps = $host->config->dateTimeInfo->ntpConfig->server;
                        my $ntp_string = "";
                        if($ntps) {
                                foreach (@$ntps) {
                                        $ntp_string .= "$_<br>";
                                }
                        } else { $ntp_string = "NONE CONFIGURED"; }
			$ntp_string = "<tr><td>".$ntp_string."</td>"; 
			$ntp_string .= "<td>".$host->config->dateTimeInfo->timeZone->description."</td><td>".$host->config->dateTimeInfo->timeZone->gmtOffset."</td><td>".$host->config->dateTimeInfo->timeZone->name."</td></tr>";
			print REPORT_OUTPUT "<tr><th>NTP</th><td><table border=1 width=100%><tr><th>NTP SERVERS</th><th>TIME ZONE</th><th>GMT OFFSET</th><th>LOCATION</th></tr>",$ntp_string,"</table></td></tr>\n";
                }

		## VSWIF ##
		if($host->config->network->consoleVnic) {
			my $vswif_string = "";
			my $console_vnics = $host->config->network->consoleVnic;
			foreach(@$console_vnics) {
				if($enable_demo_mode eq 1) {
					$vswif_string .= "<tr><td>".$_->device."</td><td>HIDE MY PG</td><td>X.X.X.X</td><td>".$_->spec->ip->subnetMask."</td><td>".$_->spec->mac."</td><td>".(($_->spec->ip->dhcp) ? "YES" : "NO")."</td></tr>";
				} else {
					$vswif_string .= "<tr><td>".$_->device."</td><td>".$_->portgroup."</td><td>".$_->spec->ip->ipAddress."</td><td>".$_->spec->ip->subnetMask."</td><td>".$_->spec->mac."</td><td>".(($_->spec->ip->dhcp) ? "YES" : "NO")."</td></tr>";
				}
			}
			print REPORT_OUTPUT "<tr><th>VSWIF(s)</th><td><table border=1 width=100%><tr><th>NAME</th><th>PORTGROUP</th><th>IP ADDRESS</th><th>NETMASK</th><th>MAC</th><th>DHCP</th></tr>",$vswif_string,"</table></td></tr>\n";
		}
	
		## VMKERNEL ##
		if($host->config->network->vnic) {
			my $vmk_string = "";
			my $vmks = $host->config->network->vnic;
			foreach(@$vmks) {
				if($enable_demo_mode eq 1) {
                                        $vmk_string .= "<tr><td>".$_->device."</td><td>HIDE MY PG</td><td>X.X.X.X</td><td>".$_->spec->ip->subnetMask."</td><td>".$_->spec->mac."</td><td>".(($_->spec->ip->dhcp) ? "YES" : "NO")."</td></tr>";
                                } else {
					$vmk_string .= "<tr><td>".$_->device."</td><td>".$_->portgroup."</td><td>".$_->spec->ip->ipAddress."</td><td>".$_->spec->ip->subnetMask."</td><td>".$_->spec->mac."</td><td>".(($_->spec->ip->dhcp) ? "YES" : "NO")."</td></tr>";
				}
			}
			print REPORT_OUTPUT "<tr><th>VMKERNEL(s)</th><td><table border=1 width=100%><tr><th>INTERFACE</th><th>PORTGROUP</th><th>IP ADDRESS</th><th>NETMASK</th><th>MAC</th><th>DHCP</th></tr>",$vmk_string,"</table></td></tr>\n";
		}
	
		## VSWITCH ##
		getVswitchInfo($host);	
	
		## SNMP ##
		my $snmp_system;
		eval { $snmp_system = Vim::get_view (mo_ref => $host->configManager->snmpSystem); };
		if(!$@) {
			if($snmp_system->configuration->enabled) {
				my $snmp_string = "";
				$snmp_string .= "<tr><td>".$snmp_system->configuration->port."</td><td>".$snmp_system->configuration->readOnlyCommunities."</td></tr>";
				my $snmp_traps = $snmp_system->configuration->trapTargets;
				foreach(@$snmp_traps) {
			        	print "Community: ", $_->commmunity, " Hostname: ", $_->hostName, " Port: ",$_->port,"\n";
				}

				print REPORT_OUTPUT "<tr><th>SNMP</th><td><table border=1 width=100%><tr><th>SNMP PORT</th><th>RO COMMUNITIES</th><th>TARGETS</th></tr>",$snmp_string,"</table></td></tr>\n";		
			}
		}
		## FIREWALL ##
		if($host->config->firewall) {	
			my $fw_sys = $host->config->firewall;
			my $fw_rules = $fw_sys->ruleset;
			my $fw_known_string = "";
			my $fw_rule_string = "";
			foreach(@$fw_rules) {
				if($_->enabled) {
					$fw_known_string .= "<tr><td>".$_->label."</td></tr>";
				}
			}
			print REPORT_OUTPUT "<tr><th>FIREWALL<br> KNOWN SERVICES ENABLED</th><td><table border=1 width=100%>",$fw_known_string,"</table></td></tr>\n";
			print REPORT_OUTPUT "<tr><th>FIREWALL<br> DEFAULT INCOMING ENABLED</th><td><table border=1 width=100%>",($fw_sys->defaultPolicy->incomingBlocked ? "YES" : "NO"),"</table></td></tr>\n";
			print REPORT_OUTPUT "<tr><th>FIREWALL<br> DEFAULT OUTGOING ENABLED</th><td><table border=1 width=100%>",($fw_sys->defaultPolicy->outgoingBlocked ? "YES" : "NO"),"</table></td></tr>\n";
		}

		## END OF CUSTOME DETAIL INFO ##

		print REPORT_OUTPUT "</table>\n";

		## CDP ##
		printCDPInfo($host->name);

		## MULTI-PATHING ##
	        printMultipathing($host);

		## HOSTD LOGS ##
		printHostdLogs($host);

		## LATEST TASK ##
		printTasks($host);
}

sub printCDPInfo {
	my ($hostName) = @_;
	if($cdp_string ne "") {
		if($opt_type eq 'detail-hosts') {
                        push @jump_tags,"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href=\"#$hostName CDP Info\">CDP Info</a><br>\n";
                        print REPORT_OUTPUT "\n<a name=\"$hostName CDP Info\"></a>\n";
                        print REPORT_OUTPUT "<H3>CDP Info:</H3>\n";
                } else { push @jump_tags,"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href=\"#ESX/ESXi CDP Info\">ESX/ESXi CDP Info</a><br>\n";
                        print REPORT_OUTPUT "\n<a name=\"ESX/ESXi CDP Info-$cluster_count\"></a>\n";
                        print REPORT_OUTPUT "<H3>ESX/ESXi CDP Info:</H3>\n"; }
                        print REPORT_OUTPUT "<table border=1>\n";
        		print REPORT_OUTPUT "<tr><th>DEVICE</th><th>MGMT ADDRESS</th><th>DEVICE ADDRESS</th><th>IP PREFIX</th><th>LOCATION</th><th>SYSTEM NAME</th><th>SYSTEM VERSION</th><th>SYSTEM OID</th><th>PLATFORM</th><th>DEVICE ID</th><th>CDP VER</th><th>FULL DUPLEX</th><th>MTU</th><th>TIMEOUT</th><th>TTL</th><th>VLAN ID</th><th>SAMPLES</th></tr>\n";
			print REPORT_OUTPUT $cdp_string;
			print REPORT_OUTPUT "</table>\n";	
        }
	$cdp_string = "";
}

sub printHostdLogs {
	my ($host) = @_;
	my $hostName;
	       if($enable_demo_mode eq 1) { $hostName = $randomHostName;
        } else { $hostName = $host->summary->config->name; }

        my $logData;
        my $logKey = "hostd";
	my $diagmgr_view = Vim::get_view(mo_ref => Vim::get_service_content()->diagnosticManager);
	if($opt_type eq 'detail-hosts') {
	   	$logData = $diagmgr_view->BrowseDiagnosticLog(key => $logKey, host => $host, start => "999999999");
	} else {
		$logData = $diagmgr_view->BrowseDiagnosticLog(key => $logKey,start => "999999999");
	}
        my $lineEnd = $logData->lineEnd;
        my $start = $lineEnd - $hostd_log_print;
	if($opt_type eq 'detail-hosts') {
		$logData = $diagmgr_view->BrowseDiagnosticLog(key => $logKey,host => $host, start => $start,lines => $hostd_log_print);
	} else {
               	$logData = $diagmgr_view->BrowseDiagnosticLog(key => $logKey,start => $start,lines => $hostd_log_print);
	}
        if ($logData->lineStart != 0) {
		if($opt_type eq 'detail-hosts') {
			push @jump_tags,"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href=\"#$hostName Hostd Logs - Last $hostd_log_print lines\">Hostd Logs - Last $hostd_log_print lines</a><br>\n";
        		print REPORT_OUTPUT "\n<a name=\"$hostName Hostd Logs - Last $hostd_log_print lines\"></a>\n";
        		print REPORT_OUTPUT "<H3>Hostd Logs - Last $hostd_log_print lines:</H3>\n";
        	} else { push @jump_tags,"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href=\"#ESX/ESXi Hostd Logs - Last $hostd_log_print lines-$cluster_count\">ESX/ESXi Hostd Logs - Last $hostd_log_print lines</a><br>\n";
        		print REPORT_OUTPUT "\n<a name=\"ESX/ESXi Hostd Logs - Last $hostd_log_print lines-$cluster_count\"></a>\n";
        		print REPORT_OUTPUT "<H3>ESX/ESXi Hostd Logs - Last $hostd_log_print lines:</H3>\n"; }
        		print REPORT_OUTPUT "<table border=1>\n";
			my $hostd_string = "";
                foreach my $line (@{$logData->lineText}) {
			$hostd_string .= $line."<br>\n";
                }
		if($enable_demo_mode eq 1) { $hostd_string = "HIDE MY IMPORTANT LOGS"; }
		print REPORT_OUTPUT "<tr><td>",$hostd_string,"</td></tr>\n";
		print REPORT_OUTPUT "</table>\n";
	}
}

sub printTasks {
	my ($host) = @_;
	my $hostName;
        if($enable_demo_mode eq 1) { $hostName = $randomHostName;
        } else { $hostName = $host->summary->config->name; }

	my $task_view = Vim::get_view(mo_ref => Vim::get_service_content()->taskManager);
	my $tasks = Vim::get_views(mo_ref_array => $task_view->recentTask);

	if($tasks) {
		if($opt_type eq 'detail-hosts') {
                        push @jump_tags,"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href=\"#$hostName Recent Tasks\">Recent Tasks</a><br>\n";
                        print REPORT_OUTPUT "\n<a name=\"$hostName Recent Tasks\"></a>\n";
                        print REPORT_OUTPUT "<H3>Recent Tasks:</H3>\n";
                } else { push @jump_tags,"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href=\"#ESX/ESXi Recent Tasks-$cluster_count\">ESX/ESXi Recent Tasks</a><br>\n";
                        print REPORT_OUTPUT "\n<a name=\"ESX/ESXi Recent Tasks-$cluster_count\"></a>\n";
                        print REPORT_OUTPUT "<H3>ESX/ESXi Recent Tasks:</H3>\n"; }
                        print REPORT_OUTPUT "<table border=1>\n";
			print REPORT_OUTPUT "<tr><th>DESCRIPTION</th><th>QUEUE TIME</th><th>START TIME</th><th>COMPLETION TIME</th><th>PROGRESS</th><th>STATE</th></tr>\n";
	}

	my $task_string = "";

	foreach(@$tasks) {
		my $progress = $_->info->progress;
		if(!defined($progress)) {
			$progress = "COMPLETED";
		}
		$task_string .= "<tr><td>".$_->info->descriptionId."</td><td>".$_->info->queueTime."</td><td>".($_->info->startTime ? $_->info->startTime : "N/A")."</td><td>".($_->info->completeTime ? $_->info->completeTime : "N/A")."</td><td>".$progress."</td><td>".$_->info->state->val."</td></tr>\n";
	}

	if($tasks) {
		if($enable_demo_mode eq 1) { $task_string = "HIDE MY RECENT TASKS"; }
		print REPORT_OUTPUT $task_string;
       		print REPORT_OUTPUT "</table>\n";
	}
}

sub printHBA {
	if(@hba_list) {
		push @jump_tags,"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href=\"#ESX/ESXi HBA(s)-$cluster_count\">ESX/ESXi HBA(s)</a><br>\n";
        	print REPORT_OUTPUT "\n<a name=\"ESX/ESXi HBA(s)-$cluster_count\"></a>\n";
        	print REPORT_OUTPUT "<H3>ESX/ESXi HBA(s)</H3>\n";
        	print REPORT_OUTPUT "<table border=1>\n";
        	print REPORT_OUTPUT "<tr><th>HOST</th><th>HBA TYPE</th><th>DEVICE</th><th>PCI</th><th>MODEL</th><th>DRIVER</th><th>STATUS</th><th>ADDITIONAL INFO</th></tr>\n";
		foreach (@hba_list) {
			print REPORT_OUTPUT "<tr>",$_,"</tr>\n";
		}
		print REPORT_OUTPUT "</table>\n";
	}
	@hba_list = ();	
}

sub printNIC {
	if(@nic_list) {
                push @jump_tags,"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href=\"#ESX/ESXi NIC(s)-$cluster_count\">ESX/ESXi NIC(s)</a><br>\n";
                print REPORT_OUTPUT "\n<a name=\"ESX/ESXi NIC(s)-$cluster_count\"></a>\n";
                print REPORT_OUTPUT "<H3>ESX/ESXi NIC(s)</H3>\n";
                print REPORT_OUTPUT "<table border=1>\n";
                print REPORT_OUTPUT "<tr><th>HOST</th><th>DEVICE</th><th>PCI</th><th>DRIVER</th><th>DUPLEX</th><th>SPEED</th><th>WOL ENABLED</th><th>MAC</th></tr>\n";
                foreach (@nic_list) {
                        print REPORT_OUTPUT "<tr>",$_,"</tr>\n";
                }
                print REPORT_OUTPUT "</table>\n";
        }
        @nic_list = ();
}

sub printHealth {
	if(@health_list) {
		push @jump_tags,"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href=\"#ESX/ESXi Health Status-$cluster_count\">ESX/ESXi Health Status</a><br>\n";
                print REPORT_OUTPUT "\n<a name=\"ESX/ESXi Health Status-$cluster_count\"></a>\n";
                print REPORT_OUTPUT "<H3>ESX/ESXi Health Status</H3>\n";
                print REPORT_OUTPUT "<table border=1>\n";
                print REPORT_OUTPUT "<tr><th>SENSOR NAME</th><th>READING</th><th>STATUS</th></tr>\n";
                foreach (@health_list) {
                        print REPORT_OUTPUT $_;
                }
                print REPORT_OUTPUT "</table>\n";
        }
        @health_list = ();
}

sub getHealthInfo {
	my ($host) = @_;
	if(defined($host->runtime->healthSystemRuntime)) {
		if(defined($host->runtime->healthSystemRuntime->systemHealthInfo)) {
			my $health_string = "";
			$health_string .= "<tr><th align=\"left\">".$host->name."</th></tr>\n";
			my $sensors = $host->runtime->healthSystemRuntime->systemHealthInfo->numericSensorInfo;
			my $sensor_health_color = "";
			foreach(sort {$a->name cmp $b->name} @$sensors) {
				my $sensor_health = $_->healthState->key;
                		if ($sensor_health eq 'Green' || $sensor_health eq 'green') { $sensor_health_color="<td bgcolor=\"green\">OK</td>"; }
                		elsif ($sensor_health_color eq 'Red' || $sensor_health_color eq 'red') { $sensor_health_color="<td bgcolor=\"red\">PROBLEM</td>"; }
               		 	elsif ($sensor_health_color eq 'Yellow' || $sensor_health_color eq 'yellow') { $sensor_health_color="<td bgcolor=\"yellow\">WARNING</td>"; }
                		else { $sensor_health_color="<td bgcolor=\"gray\">UNKNOWN</td>"; }
				my $reading;
				if(defined($_->rateUnits)) {
					$reading = $_->currentReading . " " . $_->baseUnits . "/" . $_->rateUnits;				
				} else {
					$reading = $_->currentReading . " " . $_->baseUnits;
				}
				$health_string .= "<tr><td>".$_->name."</td><td>".$reading."</td>".$sensor_health_color."</tr>\n";
			}
			push @health_list,$health_string;		
		}
	}
}

sub getNICInfo {
	my ($host) = @_;
	my $nics = $host->config->network->pnic;
	foreach my $nic (@$nics) {
		my $nic_string = "";
		if($enable_demo_mode eq 1) {
                        $nic_string = "<td>HIDE ME!</td>";
                }
                else {
                        $nic_string = "<td>".$host->name."</td>";
                }
		$nic_string .= "<td>".$nic->device."</td><td>".$nic->pci."</td><td>".$nic->driver."</td>";
		if($nic->linkSpeed) {
			$nic_string .= "<td>".(($nic->linkSpeed->duplex) ? "FULL DUPLEX" : "HALF-DUPLEX")."</td><td>".$nic->linkSpeed->speedMb." MB</td>";
		}
		else {
			$nic_string .= "<td>UNKNOWN</td><td>UNKNOWN</td>";
		}
		$nic_string .= "<td>".(($nic->wakeOnLanSupported) ? "YES" : "NO")."</td>";
		if($enable_demo_mode eq 1) {
                        $nic_string .= "<td>XX:XX:XX:XX:XX:XX</td>";
		}	
		else {
			$nic_string .= "<td>".$nic->mac."</td>";
		}
		push @nic_list,$nic_string;
	}
}

sub getHBAInfo {
	my ($host) = @_;
	my $hbas = $host->config->storageDevice->hostBusAdapter;
	foreach my $hba (@$hbas) {
		my $hba_string = "";
		if($enable_demo_mode eq 1) {
                        $hba_string = "<td>HIDE ME!</td>";
                }
                else {
                	$hba_string = "<td>".$host->name."</td>";
                }
        	if ($hba->isa("HostFibreChannelHba")) {
			my $nwwn = (Math::BigInt->new($hba->nodeWorldWideName))->as_hex();
			my $pwwn = (Math::BigInt->new($hba->portWorldWideName))->as_hex();
                        $nwwn =~ s/^..//;
			$pwwn =~ s/^..//;
                        $nwwn = join(':', unpack('A2' x 8, $nwwn));
			$pwwn = join(':', unpack('A2' x 8, $pwwn));
			if($enable_demo_mode eq 1) {
                        	$nwwn = "XX:XX:XX:XX:XX:XX:XX:XX";
                                $pwwn = "XX:XX:XX:XX:XX:XX:XX:XX";
			}
			$hba_string .= "<td>FC</td><td>".$hba->device."</td><td>".$hba->pci."</td><td>".$hba->model."</td><td>".$hba->driver."</td><td>".$hba->status."</td><td><b>NWWN</b> ".$nwwn."</td><td><b>PWWN</b> ".$pwwn."</td><td><b>PORT TYPE</b> ".$hba->portType->val."</td><td><b>SPEED</b> ".$hba->speed."</td></td>";
                } elsif ($hba->isa("HostInternetScsiHba")) {
                        $hba_string .= "<td>iSCSI</td><td>".$hba->device."</td><td>".$hba->pci."</td><td>".$hba->model."</td><td>".$hba->driver."</td><td>".$hba->status."</td><td>".(($hba->authenticationProperties->chapAuthEnabled) ? "CHAP ENABLED" : "CHAP DISABLED")."</td>";
                }
		elsif ($hba->isa("HostParallelScsiHba")) {
			$hba_string .= "<td>SCSI</td><td>".$hba->device."</td><td>".$hba->pci."</td><td>".$hba->model."</td><td>".$hba->driver."</td><td>".$hba->status."</td><td>";
		}
		elsif ($hba->isa("HostBlockHba")) {
			$hba_string .= "<td>BLOCK</td><td>".$hba->device."</td><td>".$hba->pci."</td><td>".$hba->model."</td><td>".$hba->driver."</td><td>".$hba->status."</td><td>";
		}
		push @hba_list,$hba_string;
	}
}

sub getVswitchInfo {
		my ($host) = @_;
		my %cdp_blob = ();

                my $netMgr = Vim::get_view(mo_ref => $host->configManager->networkSystem);
                my @physicalNicHintInfo = $netMgr->QueryNetworkHint();
                foreach (@physicalNicHintInfo){
                        foreach ( @{$_} ){
                                if(defined($_->connectedSwitchPort)) {
                                        my $device = $_->device;
                                        my $port = $_->connectedSwitchPort->portId;
					my $address = defined $_->connectedSwitchPort->address ? $_->connectedSwitchPort->address : "N/A";
                               		my $cdp_ver = defined $_->connectedSwitchPort->cdpVersion ? $_->connectedSwitchPort->cdpVersion : "N/A";
                                	my $devid = defined $_->connectedSwitchPort->devId ? $_->connectedSwitchPort->devId : "N/A";
	                                my $duplex = defined $_->connectedSwitchPort->fullDuplex ? ($_->connectedSwitchPort->fullDuplex ? "YES" : "NO") : "N/A";
        	                        my $platform = defined $_->connectedSwitchPort->hardwarePlatform ? $_->connectedSwitchPort->hardwarePlatform : "N/A";
                	                my $prefix = defined $_->connectedSwitchPort->ipPrefix ? $_->connectedSwitchPort->ipPrefix : "N/A";
                        	        my $location = defined $_->connectedSwitchPort->location ? $_->connectedSwitchPort->location : "N/A";
                                	my $mgmt_addr = defined $_->connectedSwitchPort->mgmtAddr ? $_->connectedSwitchPort->mgmtAddr : "N/A";
	                                my $d_mtu = defined $_->connectedSwitchPort->mtu ? $_->connectedSwitchPort->mtu : "N/A";
        	                        my $samples = defined $_->connectedSwitchPort->samples ? $_->connectedSwitchPort->samples : "N/A";
                	                my $sys_ver = defined $_->connectedSwitchPort->softwareVersion ? $_->connectedSwitchPort->softwareVersion : "N/A";
                        	        my $sys_name = defined $_->connectedSwitchPort->systemName ? $_->connectedSwitchPort->systemName : "N/A";
                                	my $sys_oid = defined $_->connectedSwitchPort->systemOID ? $_->connectedSwitchPort->systemOID : "N/A";
	                                my $timeout = defined $_->connectedSwitchPort->timeout ? $_->connectedSwitchPort->timeout : "N/A";
	                                my $ttl = defined $_->connectedSwitchPort->ttl ? $_->connectedSwitchPort->ttl : "N/A";
	                                my $vlan = defined $_->connectedSwitchPort->vlan ? $_->connectedSwitchPort->vlan : "N/A";
	                                my $blob .= "<tr><td>".$device."</td><td>".$mgmt_addr."</td><td>".$address."</td><td>".$prefix."</td><td>".$location."</td><td>".$sys_name."</td><td>".$sys_ver."</td><td>".$sys_oid."</td><td>".$platform."</td><td>".$devid."</td><td>".$cdp_ver."</td><td>".$duplex."</td><td>".$d_mtu."</td><td>".$timeout."</td><td>".$ttl."</td><td>".$vlan."</td><td>".$samples."</td></tr>\n";
        	                        $cdp_blob{$device} = $blob;
                                        $cdp_enabled{$device} = $port;
                                }
                        }
                }

                my $vswitches = $host->config->network->vswitch;
		my $vswitch_string = "";
                foreach my $vSwitch (@$vswitches) {
                        my $pNicName = "";
                        my $mtu = "";
                        my $cdp_vswitch = "";

                        my $pNics = $vSwitch->pnic;
                        my $pNicKey = "";
                        foreach (@$pNics) {
                                $pNicKey = $_;
                                if ($pNicKey ne "") {
                                        $pNics = $netMgr->networkInfo->pnic;
                                        foreach my $pNic (@$pNics) {
                                                if ($pNic->key eq $pNicKey) {
                                                        $pNicName = $pNicName ? ("$pNicName," . $pNic->device) : $pNic->device;
                                                        if($cdp_enabled{$pNic->device}) {
                                                                $cdp_vswitch = $cdp_enabled{$pNic->device};
                                                        }
                                                        else {
                                                                $cdp_vswitch = "";
                                                        }
                                                }
                                        }
                                }
                        }
                        $mtu = $vSwitch->{mtu} if defined($vSwitch->{mtu});
			$vswitch_string .= "<tr><th>VSWITCH NAME</th><th>NUM OF PORTS</th><th>USED PORTS</th><th>MTU</th><th>UPLINKS</th><th>CDP ENABLED</th></tr><tr><td>".$vSwitch->name."</td><td>".$vSwitch->numPorts."</td><td>".($vSwitch->numPorts - $vSwitch->numPortsAvailable)."</td><td>".$vSwitch->{mtu}."</td><td>".$pNicName."</td><td>".$cdp_vswitch."</td></tr>";
			$vswitch_string .= "<tr><th>PORTGROUP NAME</th><th>VLAN ID</th><th>USED PORTS</th><th colspan=3>UPLINKS</th></tr>";
 
                        my $portGroups = $vSwitch->portgroup;
                        foreach my $port (@$portGroups) {
                                my $pg = FindPortGroupbyKey ($netMgr, $vSwitch->key, $port);
                                next unless (defined $pg);
                                my $usedPorts = (defined $pg->port) ? $#{$pg->port} + 1 : 0;
				if($enable_demo_mode eq 1) {
					$vswitch_string .= "<tr><td>HIDE MY PG</td><td>HIDE MY VLAN ID</td><td>".$usedPorts."</td><td colspan=3>".$pNicName."</td></tr>";
				} else {
					$vswitch_string .= "<tr><td>".$pg->spec->name."</td><td>".$pg->spec->vlanId."</td><td>".$usedPorts."</td><td colspan=3>".$pNicName."</td></tr>";	
				}
                        }
                }
		print REPORT_OUTPUT "<tr><th>VSWITCH(s)</th><td><table border=1>",$vswitch_string,"</table></td></tr>\n";

        	for my $key ( keys %cdp_blob ) {
                	my $value = $cdp_blob{$key};
                	$cdp_string .= $value;
        	}
}

sub FindPortGroupbyKey {
   my ($network, $vSwitch, $key) = @_;
   my $portGroups = $network->networkInfo->portgroup;
   foreach my $pg (@$portGroups) {
      return $pg if (($pg->vswitch eq $vSwitch) && ($key eq $pg->key));
   }
   return undef;
}

sub printClusterSummary {
	my ($local_cluster) = @_;
        my $cluster_name = $local_cluster->name;
	my $cluster_health = $local_cluster->overallStatus->val;
        my $cluster_host_cnt = $local_cluster->summary->numHosts;
        my $cluster_avail_host = $local_cluster->summary->numEffectiveHosts;
	my $cluster_cpu_cnt = prettyPrintData($local_cluster->summary->totalCpu,'MHZ');
	my $cluster_mem_cnt = prettyPrintData($local_cluster->summary->totalMemory,'B');
	my $cluster_avail_cpu = prettyPrintData($local_cluster->summary->effectiveCpu,'MHZ');
	my $cluster_avail_mem = prettyPrintData($local_cluster->summary->effectiveMemory,'M');
	my $cluster_drs = $local_cluster->configuration->drsConfig->enabled;
	my $cluster_ha = $local_cluster->configuration->dasConfig->enabled;
	my $cluster_dpm = $local_cluster->configurationEx->dpmConfigInfo->enabled;
	my $cpu_perc_string = "";
        my $mem_perc_string = "";

	clusterPG($local_cluster);

        print REPORT_OUTPUT "<hr>\n";

        ###########################
        # PRINT CLUSTER SUMMARY
        ###########################
	push @jump_tags,"CL<a href=\"#$cluster_name\">Cluster: $cluster_name</a><br>\n";
	print REPORT_OUTPUT "\n<a name=\"$cluster_name\"></a>\n";
        print REPORT_OUTPUT "<H2>Cluster: $cluster_name</H2>\n";
        print REPORT_OUTPUT "<H3>Cluster Statistics:</H3>\n";
        print REPORT_OUTPUT "<table border=1>\n";
        print REPORT_OUTPUT "<tr><th>CLUSTER HEALTH</th><th>AVAILABLE HOST(s)</th><th>AVAILABLE CPU</th><th>AVAILABLE MEM</th><th>DRS ENABLED</th><th>HA ENABLED</th><th>DPM ENABLED</th></tr>\n";
        print REPORT_OUTPUT "<tr>";
	if($cluster_health eq 'gray' ) { print REPORT_OUTPUT "<td bgcolor=gray>UNKNOWN"; }
        if($cluster_health eq 'green' ) { print REPORT_OUTPUT "<td bgcolor=green>CLUSTER OK"; }
        if($cluster_health eq 'red' ) { print REPORT_OUTPUT "<td bgcolor=red>CLUSTER HAS PROBLEM"; }
        if($cluster_health eq 'yellow' ) { print REPORT_OUTPUT "<td bgcolor=yellow>CLUSTER MIGHT HAVE PROBLEM"; }
        print REPORT_OUTPUT "<td>",$cluster_avail_host,"/",$cluster_host_cnt,"</td>";
        print REPORT_OUTPUT "<td>",$cluster_avail_cpu,"</td>";
        print REPORT_OUTPUT "<td>",$cluster_avail_mem,"</td>";
	print REPORT_OUTPUT "<td>",($cluster_drs) ? "YES" : "NO","</td>";
	print REPORT_OUTPUT "<td>",($cluster_ha) ? "YES" : "NO" ,"</td>";
	print REPORT_OUTPUT "<td>",($cluster_dpm) ? "YES" : "NO" ,"</td>";
	print REPORT_OUTPUT "</tr>\n";
	print REPORT_OUTPUT "</table>\n";

        ###########################
        # PRINT HA INFO
        ###########################
        if($cluster_ha) {
                print REPORT_OUTPUT "\n<H3>HA CONFIGURATIONS:</H3>\n";
                print REPORT_OUTPUT "<table border=1>\n";
                print REPORT_OUTPUT "<tr><th>FAILOVER LEVEL</th><th>ADMISSION CONTROLED ENABLED</th><th>ISOLATION RESPONSE</th><th>RESTART PRIORITY</th></tr>\n";
                print REPORT_OUTPUT "<td>",$local_cluster->configuration->dasConfig->failoverLevel,"</td>";
                print REPORT_OUTPUT "<td>",($local_cluster->configuration->dasConfig->admissionControlEnabled) ? "YES" : "NO","</td>";
                print REPORT_OUTPUT "<td>",$local_cluster->configuration->dasConfig->defaultVmSettings->isolationResponse,"</td>";
                print REPORT_OUTPUT "<td>",$local_cluster->configuration->dasConfig->defaultVmSettings->restartPriority,"</td>";
		print REPORT_OUTPUT "</tr>\n";
                print REPORT_OUTPUT "</table>\n";
        }

	###########################
        # PRINT DRS INFO 
        ###########################
	if($cluster_drs) {
        	print REPORT_OUTPUT "\n<H3>DRS CONFIGURATIONS:</H3>\n";
        	print REPORT_OUTPUT "<table border=1>\n";
        	print REPORT_OUTPUT "<tr><th>DRS BEHAVIOR</th><th>VMOTION RATE</th></tr>\n";
		print REPORT_OUTPUT "<tr><td>",$local_cluster->configuration->drsConfig->defaultVmBehavior->val,"</td>";
		print REPORT_OUTPUT "<td>",$local_cluster->configuration->drsConfig->vmotionRate,"</td>";
		print REPORT_OUTPUT "</tr>\n";
		print REPORT_OUTPUT "</table>\n";
		
		#my $drs_migrations = $local_cluster->migrationHistory;
		#foreach (@$drs_migrations) {
		#	print $_->time,"\n";
		#}
	}

	###########################
        # PRINT DPM INFO
        ###########################
        if($cluster_dpm) {
		print REPORT_OUTPUT "\n<H3>DRS CONFIGURATIONS:</H3>\n";
                print REPORT_OUTPUT "<table border=1>\n";
                print REPORT_OUTPUT "<tr><th>DPM BEHAVIOR</th></tr>\n";
		print REPORT_OUTPUT "<td>",$local_cluster->configurationEx->dpmConfigInfo->defaultDpmBehavior->val,"</td>";
		print REPORT_OUTPUT "</tr>\n";
		print REPORT_OUTPUT "</table>\n";
	}

        ###########################
        # PRINT CLUSTER RULES
        ###########################
        my $rules = $local_cluster->configurationEx->rule;
        if($rules) {
                print REPORT_OUTPUT "\n<H3>Cluster Rules:</H3>\n";
                print REPORT_OUTPUT "<table border=1>\n";
                print REPORT_OUTPUT "<tr><th>RULE NAME</th><th>RULE TYPE</th><th>ENABLED</th></tr>\n";
                foreach (@$rules) {
                        my $rule = $_;
                        my $is_enabled = $rule->enabled;
                        my $rule_name = $rule->name;
			my $rule_type;
			if(ref($rule) eq 'ClusterAffinityRuleSpec') {
				$rule_type = "AFFINITY";
			}
			elsif (ref($rule) eq 'ClusterAntiAffinityRuleSpec') {
				$rule_type = "ANTI-AFFINITY";
			}
                        print REPORT_OUTPUT "<tr><td>",$rule_name,"</td><td>",$rule_type,"</td><td>",($is_enabled) ? "YES" : "NO","</td></tr>\n";
                }
                print REPORT_OUTPUT "</table>\n";
        }

	###########################
        # PRINT RPS INFO
        ###########################
	my $root_rp = Vim::get_view (mo_ref => $local_cluster->resourcePool);
        my $rps = Vim::get_views (mo_ref_array => $root_rp->resourcePool);
	if(@$rps > 0) {
		print REPORT_OUTPUT "\n<H3>Root Resource Pool(s):</H3>\n";
                print REPORT_OUTPUT "<table border=1>\n";
                print REPORT_OUTPUT "<tr><th>POOL NAME</th><th>STATUS</th><th>CPU LIMIT</th><th>CPU RESERVATION</th><th>MEM LIMIT</th><th>MEM RESERVATION</th><th>CPU USAGE</th><th>CPU MAX</th><th>MEM USAGE</th><th>MEM MAX</th></tr>\n";
        	foreach (@$rps) {
                	my $rp_name = $_->name;
			my $rp_status = $_->summary->runtime->overallStatus->val;
			if($rp_status eq 'gray') { $rp_status = "<td bgcolor=\"gray\">UNKNOWN</td>"; }
			elsif($rp_status eq 'green') { $rp_status = "<td bgcolor=\"green\">UNDERCOMMITTED</td>";  }
			elsif($rp_status eq 'red') { $rp_status = "<td bgcolor=\"red\">INCONSISTENT</td>"; }
			elsif($rp_status eq 'yellow') { $rp_status = "<td bcolor=\"yellow\">OVERCOMMITTED</td>"; }
			my $rp_cpu_use = prettyPrintData($_->summary->runtime->cpu->overallUsage,'MHZ');
			my $rp_cpu_max = prettyPrintData($_->summary->runtime->cpu->maxUsage,'MHZ');
			my $rp_cpu_lim = prettyPrintData($_->summary->config->cpuAllocation->limit,'MHZ');
			my $rp_cpu_rsv = prettyPrintData($_->summary->config->cpuAllocation->reservation,'MHZ');
			my $rp_mem_use = prettyPrintData($_->summary->runtime->memory->overallUsage,'B');
			my $rp_mem_max = prettyPrintData($_->summary->runtime->memory->maxUsage,'B');
			my $rp_mem_lim = prettyPrintData($_->summary->config->cpuAllocation->limit,'M');
                        my $rp_mem_rsv = prettyPrintData($_->summary->config->cpuAllocation->reservation,'M');
			print REPORT_OUTPUT "<tr><td>",$rp_name,"</td>",$rp_status,"<td>",$rp_cpu_lim,"</td><td>",$rp_cpu_rsv,"</td><td>",$rp_mem_lim,"</td><td>",$rp_mem_rsv,"</td><td>",$rp_cpu_use,"</td><td>",$rp_cpu_max,"</td><td>",$rp_mem_use,"</td><td>",$rp_mem_max,"</td></tr>\n";
        	}
		print REPORT_OUTPUT "</table>\n";
	}
}

sub printBuildSummary {
	my $print_type;
	if ($content->about->apiType eq 'VirtualCenter') {	
		$print_type = "VMware vCenter";
	}
	else {
		$print_type = "VMware ESX/ESXi";
	}

	print REPORT_OUTPUT "<H2>$print_type:</H2>\n";
        print REPORT_OUTPUT "<table border=1>\n";
        print REPORT_OUTPUT "<tr><th>BUILD</th><th>VERSION</th><th>FULL NAME</th>\n";
	print REPORT_OUTPUT "<tr>";
	print REPORT_OUTPUT "<td>",$content->about->build,"</td><td>",$content->about->version,"</td><td>",$content->about->fullName,"</td>\n";
	print REPORT_OUTPUT "</tr>";
	print REPORT_OUTPUT "</table>\n";

	my $lic_mgr = Vim::get_view (mo_ref => $content->licenseManager);
	print REPORT_OUTPUT "<H3>Licenses:</H3>\n";
        print REPORT_OUTPUT "<table border=1>\n";
        print REPORT_OUTPUT "<tr><th>EDITION: </th><td>",$lic_mgr->licensedEdition,"</td></tr>\n";
	if(!$enable_demo_mode eq 1) {
		my $lic_src = $lic_mgr->source;
		if(defined($lic_src)) {
	        	if($lic_src->isa('EvaluationLicenseSource')) {
        	        	print REPORT_OUTPUT "<tr><th>EVAL (hours remaining): </th><td>",$lic_src->remainingHours,"</td></tr>\n";
        		}
	        	elsif($lic_src->isa('LicenseServerSource')) {
        	        	print REPORT_OUTPUT "<tr><th>LICENSE SERVER: </th><td>",$lic_src->licenseServer,"</td></tr>\n";
        		}
	        	elsif($lic_src->isa('LocalLicenseSource')) {
        	        	print REPORT_OUTPUT "<tr><th>LICENSE KEY: </th><td>",$lic_src->licenseKeys,"</td></tr>\n";
       			}
		} else { print REPORT_OUTPUT "<tr><th>TYPE</th><td>UNKNOWN</td></tr>\n"; }
	} else { print REPORT_OUTPUT "<tr><th>TYPE</th><td>CONFIDENTIAL</td></tr>\n"; }
	print REPORT_OUTPUT "</table>\n";

	print REPORT_OUTPUT "<table border=1>\n";
	print REPORT_OUTPUT "<tr><th>FEATURE</th><th>CONSUMED</th><th>AVAILABLE</th><th>TOTAL</th>\n";
	if(!$enable_demo_mode eq 1) {
		my $lic_avail;
		eval { $lic_avail = $lic_mgr->QueryLicenseSourceAvailability(); };
		if(!$@) {
	        	foreach(@$lic_avail) {
				my $consumed = ($_->total - $_->available);
				print REPORT_OUTPUT "<tr><td>",$_->feature->featureName,"</td><td>",$consumed,"</td><td>",$_->available,"</td><td>",$_->total,"</td></tr>\n";
			}
		} else { print REPORT_OUTPUT "<tr><td>UNKNOWN</td><td>UNKNOWN</td><td>UNKNOWN</td><td>UNKNOWN</td></tr>\n"; }
	} else { print REPORT_OUTPUT "<tr><td>CONFIDENTIAL</td><td>A</td><td>B</td><td>C</td></tr>\n"; }
	print REPORT_OUTPUT "</table>\n";

	print REPORT_OUTPUT "<table border=1>\n";
	print REPORT_OUTPUT "<H3>Active Session(s):</H3>\n";
        print REPORT_OUTPUT "<tr><th>USERNAME</th><th>FULL NAME</th><th>LOGON TIME</th><th>LAST ACTIVE</th></tr>\n";
	if(!$enable_demo_mode eq 1) {
		my $sess_mgr = Vim::get_view (mo_ref => $content->sessionManager);
		my $sess_list = $sess_mgr->sessionList;
		foreach(@$sess_list) {
			print REPORT_OUTPUT "<tr><td>",$_->userName,"</td><td>",$_->fullName,"</td><td>",$_->loginTime,"</td><td>",$_->lastActiveTime,"</td></tr>\n";
		}
	} else { print REPORT_OUTPUT "<tr><td>USER X</td><td>X</td><td>TIME Y</td><td>TIME Z</td></tr>\n"; }
        print REPORT_OUTPUT "</table><br>\n";
	#please do not touch this, else the jump tags will break
	print REPORT_OUTPUT "\n/<!-- insert here -->/\n";
}

sub printDatacenterName {
	my ($dc) = @_;
	print REPORT_OUTPUT "\n<br>\n<H2>Datacenter: $dc</H2>\n";
}

sub printStartHeader {
	print "Generating VMware Health Report $version \"$report_name\" ...\n\n";
        print "This can take a few minutes depending on environment size. \nGet a cup of coffee/tea and check out http://www.engineering.ucsb.edu/~duonglt/vmware/\n";
	
	$my_time = "Date: ".giveMeDate('MDYHMS');

	$start_time = time();
	open(REPORT_OUTPUT, ">$report_name");
	print REPORT_OUTPUT "<html>\n";
	print REPORT_OUTPUT "<title>VMware Health Check Report $version - $my_time</title>\n";
	print REPORT_OUTPUT "<META NAME=\"AUTHOR\" CONTENT=\"William Lam\">\n";
	print REPORT_OUTPUT "<style type=\"text/css\">\n";
	print REPORT_OUTPUT "body { background-color:#EEEEEE; }\n";
	print REPORT_OUTPUT "body,table,td,th { font-family:Tahoma; color:Black; Font-Size:10pt }\n";
	print REPORT_OUTPUT "th { font-weight:bold; background-color:#CCCCCC; }\n";
	print REPORT_OUTPUT "a:link { color: blue; }\n";
	print REPORT_OUTPUT "a:visited { color: blue; }\n";
	print REPORT_OUTPUT "a:hover { color: blue; }\n";
	print REPORT_OUTPUT "a:active { color: blue; }\n";
	print REPORT_OUTPUT "</style>\n";

	print REPORT_OUTPUT "\n<H1>VMware Health Check Report $version</H1>\n";
	print REPORT_OUTPUT "$my_time\n";
}

sub giveMeDate {
	my ($date_format) = @_;
	my %dttime = ();
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
        	$my_time = "$dttime{mon}-$dttime{mday}-$dttime{year} $dttime{hour}:$dttime{min}:$dttime{sec}";
	}
	elsif ($date_format eq 'YMD') {
		$my_time = "$dttime{year}-$dttime{mon}-$dttime{mday}";
	}
	return $my_time;
}

sub printCloseHeader {
	print REPORT_OUTPUT "<br><hr>\n";
	print REPORT_OUTPUT "<center>Author: <b><a href=\"http://engineering.ucsb.edu/~duonglt/vmware/\">William Lam</a></b></center>\n";
	print REPORT_OUTPUT "<center>Generated using: <b><a href=\"http://communities.vmware.com/docs/DOC-9420\">vmwareHealthCheck.pl</a></b></center>\n";
	print REPORT_OUTPUT "<center>&#0153;Primp Industries</center>\n";
	close(REPORT_OUTPUT);

	my @lines;
	my $jump_string = "";
	tie @lines, 'Tie::File', $report_name or die;
	for (@lines) {
        	if (/<!-- insert here -->/) {
                	foreach (@jump_tags) {
                        	if( ($_ =~ /^CL/) ) {
                                	my $tmp_string = substr($_,2);
                                	$jump_string .= $tmp_string;
                        	}
                        	else {
                                	$jump_string .= $_;
                        	}
                	}
                	$_ = "\n$jump_string";
                	last;
        	}
	}
	untie @lines;

	$end_time = time();
	$run_time = $end_time - $start_time;
	print "\nStart Time: ",&formatTime(str => scalar localtime($start_time)),"\n";
	print "End   Time: ",&formatTime(str => scalar localtime($end_time)),"\n";

	if ($run_time < 60) {
        	print "Duration  : ",$run_time," Seconds\n\n";
	}
	else {
		print "Duration  : ",&restrict_num_decimal_digits($run_time/60,2)," Minutes\n\n";
	}
}

sub cleanUp {
	@hosts_seen = ();
}

sub Fail {
    my ($msg) = @_;
    Util::disconnect();
    die ($msg);
    exit ();
}

sub getColor {
	my ($val) = @_;
	my $color_string = "";
	if($val < $red_warn) { $color_string = "<td bgcolor=\"red\">".$val." %</td>"; }
	elsif($val < $orange_warn) { $color_string = "<td bgcolor=\"orange\">".$val." %</td>"; }
	elsif($val < $yellow_warn) { $color_string = "<td bgcolor=\"yellow\">".$val." %</td>"; }
        else { $color_string = "<td>".$val." %</td>"; }

	return $color_string;
}

sub setSnapColor {
	my ($val,$datastore,$snapshot,$size,$date) = @_;
	$size = prettyPrintData($size,'B');
        my $snap_color_string = "";
        if($val > $snap_red_warn) { $snap_color_string = "<td>".$datastore."</td><td>".$snapshot."</td><td bgcolor=\"red\">".$val." days old</td><td>".$size."</td><td>".$date."</td>"; }
        elsif($val > $snap_orange_warn) { $snap_color_string = "<td>".$datastore."</td><td>".$snapshot."</td><td bgcolor=\"orange\">".$val." days old</td><td>".$size."</td><td>".$date."</td>"; }
        elsif($val > $snap_yellow_warn) { $snap_color_string = "<td>".$datastore."</td><td>".$snapshot."</td><td bgcolor=\"yellow\">".$val." days old</td><td>".$size."</td><td>".$date."</td>"; }
	if(!$snap_color_string eq '') {
		push @vm_delta_warn,$snap_color_string;
	}
}

#http://www.bryantmcgill.com/Shazam_Perl_Module/Subroutines/utils_convert_bytes_to_optimal_unit.html
sub prettyPrintData{
	my($bytes,$type) = @_;

  	return '' if ($bytes eq '' || $type eq '');
	return 0 if ($bytes <= 0);

  	my($size);

	if($type eq 'B') {
  		$size = $bytes . ' Bytes' if ($bytes < 1024);
  		$size = sprintf("%.2f", ($bytes/1024)) . ' KB' if ($bytes >= 1024 && $bytes < 1048576);
  		$size = sprintf("%.2f", ($bytes/1048576)) . ' MB' if ($bytes >= 1048576 && $bytes < 1073741824);
  		$size = sprintf("%.2f", ($bytes/1073741824)) . ' GB' if ($bytes >= 1073741824 && $bytes < 1099511627776);
  		$size = sprintf("%.2f", ($bytes/1099511627776)) . ' TB' if ($bytes >= 1099511627776);
	}
	elsif($type eq 'M') {
		$bytes = $bytes * (1048576);
		$size = sprintf("%.2f", ($bytes/1048576)) . ' MB' if ($bytes >= 1048576 && $bytes < 1073741824);
                $size = sprintf("%.2f", ($bytes/1073741824)) . ' GB' if ($bytes >= 1073741824 && $bytes < 1099511627776);
                $size = sprintf("%.2f", ($bytes/1099511627776)) . ' TB' if ($bytes >= 1099511627776);
	}

	elsif($type eq 'G') {
		$bytes = $bytes * (1073741824);
		$size = sprintf("%.2f", ($bytes/1073741824)) . ' GB' if ($bytes >= 1073741824 && $bytes < 1099511627776);
                $size = sprintf("%.2f", ($bytes/1099511627776)) . ' TB' if ($bytes >= 1099511627776);
	}
	elsif($type eq 'MHZ') {
		$size = sprintf("%.2f", ($bytes/1e-06)) . ' MHz' if ($bytes >= 1e-06 && $bytes < 0.001);
		$size = sprintf("%.2f", ($bytes*0.001)) . ' GHz' if ($bytes >= 0.001);
	}

  	return $size;
}

# restrict the number of digits after the decimal point
#http://guymal.com/mycode/perl_restrict_digits.shtml
sub restrict_num_decimal_digits {
	my $num=shift;#the number to work on
  	my $digs_to_cut=shift;# the number of digits after

  	if ($num=~/\d+\.(\d){$digs_to_cut,}/) {
    		$num=sprintf("%.".($digs_to_cut-1)."f", $num);
  	}
  	return $num;
}

#http://www.infocopter.com/perl/format-time.html
sub formatTime(%) {
        my %args = @_;
        $args{'str'} ||= ''; # e.g. Mon Jul 3 12:59:28 2006

        my @elems = ();
        foreach (split / /, $args{'str'}) {
                next unless $_;
                push(@elems, $_);
        }

        my ($weekday, $month, $mday, $time, $yyyy) = split / /, join(' ', @elems);

        my %months = (  Jan => 1, Feb => 2, Mar => 3, Apr =>  4, May =>  5, Jun =>  6,
                        Jul => 7, Aug => 8, Sep => 9, Oct => 10, Nov => 11, Dec => 12 );

        my $s  = substr($time, 6,2);
        my $m  = substr($time, 3,2);
        my $h  = substr($time, 0, 2);
        my $dd = sprintf('%02d', $mday);

        my $mm_num = sprintf('%02d', $months{$month});

        my $formatted = "$mm_num\-$dd\-$yyyy $h:$m:$s";
        #my $formatted = "$yyyy$mm_num$dd$h$m$s";

        $formatted;
}

sub print_tree {
        my ($vm, $ref, $tree) = @_;
        my $head = " ";
        foreach my $node (@$tree) {
                $head = ($ref->value eq $node->snapshot->value) ? " " : " " if (defined $ref);
                my $quiesced = ($node->quiesced) ? "YES" : "NO";
                my $desc = $node->description;
                if($desc eq "" ) { $desc = "NO DESCRIPTION"; }
                push @snapshot_vms,"<td>".$vm."</td><td>".$node->name."</td><td>".$desc."</td><td>".$node->createTime."</td><td>".$node->state->val."</td><td>".$quiesced."</td>";
                print_tree ($vm, $ref, $node->childSnapshotList);
        }
        return;
}


=head1 NAME

vmwareHealthCheck.pl - Generate VMware health check against vCenter Cluster(s). 

=head1 SYNOPSIS

vmwareHealthCheck.pl [--cluster "CLUSTER_NAME"]

=head1 DESCRIPTION

This script will generate a health check html report on each of the vCenter Cluster(s) for all residing ESX/ESXi hosts.

=head1 OPTIONS

=head1 EXAMPLES

List all of the connected cdrom devices on host abc.

      vmwareHealthCheck.pl --server "vCENTER_SERVER" --username "vCenter_USERNAME" --password "vCENTER_PASSWORD" 

=head1 SUPPORTED PLATFORMS

All operations are supported on ESX 3.5 and VirtualCenter 2.5 and better.
