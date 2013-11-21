#!/usr/bin/perl -w
##################################################################
# Author: William Lam
# Email: william2003[at]gmail[dot]com
# Created on: 02/21/2009
# http://www.engineering.ucsb.edu/~duonglt/vmware/
##################################################################

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../";
use Text::ParseWords;
use VMware::VIRuntime;
use VMware::VIFPLib;
use Config;
use threads; 
use threads::shared;
use Thread::Semaphore;
use Class::Struct;
use Net::SMTP;

#############################
###  USER CONFIGURATIONS  ###
#############################

#################
# EMAIL CONF
#################

my $SEND_MAIL = "no";
my $EMAIL_HOST = "emailserver";
my $EMAIL_DOMAIN = "localhost.localdomain";
my $EMAIL_TO = 'William Lam <william@primp-industries.com.com>';
my $EMAIL_FROM = 'ghettoVCBg2 <ghettoVCBg2@primp-industries.com.com>';

###############################################################
# NAME OF THE BACKUP DATASTORE
###############################################################

my $VM_BACKUP_DATASTORE = "esx4-1-local-storage-1";

###############################################################
# BACKUP DIRECTORY NAME ON DATASTORE
###############################################################

my $VM_BACKUP_DIRECTORY = "WILLIAM_BACKUPS"; 

####################################################
# Number of backups for a given VM before deleting
####################################################

my $VM_BACKUP_ROTATION_COUNT = "3";

###################################################
# Supported backup types
# 'zeroedthick' 'eagerzeroedthick' 'thin' '2gbsparse'
###################################################

my $DISK_BACKUP_FORMAT = "thin";

###################################################
# Supported adapter types
# 'buslogic' 'lsilogic'
###################################################
my $ADAPTER_FORMAT = "buslogic";

###################################################################################################
# Shutdown guestOS prior to running backups and power them back on afterwards
# This feature assumes VMware Tools are installed, else hard power down will be initiated
# 1=enable, 0=disable (disable by default)
###################################################################################################

my $POWER_VM_DOWN_BEFORE_BACKUP = "0";

##############################################################
# VM BACKUP DIRECTORY NAMING CONVENTION (default -YYYY-MM-DD)
##############################################################

my $VM_BACKUP_DIR_NAMING_CONVENTION = timeStamp('YMD');

###################################################
# VM Snapshot Memory & Quiesce
# 1=enable, 0=disable (disable by default)
###################################################
my $VM_SNAPSHOT_MEMORY = "0";
my $VM_SNAPSHOT_QUIESCE = "0";

################################################
# LOG LEVEL VERBOSITY : "debug" or "info"
################################################

my $LOG_LEVEL = "debug";

########################## DO NOT MODIFY PAST THIS LINE ##########################

#####################
# GLOBAL VARIABLES 
####################
my @vm_backup_list = ();
my %success_backups = ();
my $host_view;
my $host_type;
my $content;
my $host;
my $vmlist;
my $enable_dryrun; 
my $backup_log_output: shared = "/dev/null"; 
my $configDir;
my $host_username;
my $host_password;
my $vima_ver;
my %host_to_vm = ();
my %vmdk_type = ();
my $optsPassed ="no";

# log level
my %loglevel=(
	"debug"   => 1,
	"info"    => 2,
	"warn"    => 3,
	"error"   => 4,
	"fatal"   => 5,
);

my $LOGLEVEL: shared = $loglevel{$LOG_LEVEL};
my $VM_VMDK_FILES = "all"; 

#####################
# interprocess communication
#VARIABLES, Datastructure 
####################
$Config{useithreads} or die "Recompile Perl with threads to run this program.";

my $semCopyTaskStart = Thread::Semaphore->new(0);
my $semWaitCopy = Thread::Semaphore->new(0);
my $semLog      = Thread::Semaphore->new(1);
my $copyThreadStatus: shared = "wait";
my $copyCmd: shared; 

#####################
#create a Copy Thread
####################
my $thr = threads->new(\&copyTask);

my $ver = "4.3";
$Util::script_version = $ver;

my %opts = (
	vmlist => {
	type => "=s",
	help => "A file containing a list of virtual machine(s) to be backed up on host",
	required => 1,
	},
	output => {
	type => "=s",
	default => "/tmp/ghettoVCBg2.log",
        help => "Full path to output log (default /tmp/ghettoVCBg2.log)",
	required => 0,
	},
	dryrun => {
	type => "=s",
	default => "0",
        help => "Set to 1 to enable dryrun mode (default 0)",
	required => 0,
	},
	config_dir => {
	type => "=s",
	help => "Name of directory containing VM(s) backup configurations",
	required => 0,
	},
);

Opts::add_options(%opts);
Opts::parse();
Opts::set_option("passthroughauth", 1);
Opts::validate();

$SIG{__DIE__} = sub{
        Util::disconnect();
        if($optsPassed eq "no") {
                &cleanUp();
        }
};

$vmlist = Opts::get_option('vmlist');
$enable_dryrun = Opts::get_option('dryrun');
$backup_log_output = Opts::get_option('output');

if(Opts::option_is_set('config_dir')) {
	$configDir = Opts::get_option('config_dir');
}

$optsPassed = "yes";

#only validate if we're not using a config
if(defined($configDir)) {
	#validate all required params are populated
	if( $VM_BACKUP_DATASTORE eq "" || $VM_BACKUP_DIRECTORY eq "" || $VM_BACKUP_ROTATION_COUNT eq "" || $DISK_BACKUP_FORMAT eq "" || $ADAPTER_FORMAT eq "" || $POWER_VM_DOWN_BEFORE_BACKUP eq "" || $LOG_LEVEL eq ""  ) {
		print "\nA required variable has not been defined, plesae go back and verify!\n";
		exit;
	}
}

#retrieve all VIMA targets
my @vima_targets = ();

#validate vima host to figure out which version to setup the commands
my $vifs_cmd;
my $vmkfstools_cmd;

if(-f "/etc/vima-release") {
	open(VIMA_REL, "/etc/vima-release") || die "Couldn't open the /etc/vima-release!";
} elsif(-f "/etc/vma-release") {
	open(VIMA_REL, "/etc/vma-release") || die "Couldn't open the /etc/vma-release!";
}

while (<VIMA_REL>) {
	my $line = $_;
	my ($prod, $ver, $build) = split(' ',$line);	
	$vima_ver = $ver;
	last if $. == 1;
}
close(VIMA_REL);

if($vima_ver eq "1.0.0") {
	$vifs_cmd = "/usr/bin/vifs.pl";
	$vmkfstools_cmd = "/usr/bin/vmkfstools.pl";
	@vima_targets = VIFPLib::enumerate_targets();
} elsif($vima_ver eq "4.0.0") {
	$vifs_cmd = "/usr/bin/vifs";
	$vmkfstools_cmd = "/usr/bin/vmkfstools";
	@vima_targets = VIFPLib::enumerate_targets();
} elsif($vima_ver eq "4.1.0") {
	$vifs_cmd = "/usr/bin/vifs";
        $vmkfstools_cmd = "/usr/bin/vmkfstools";
	@vima_targets = VmaTargetLib::enumerate_targets();
} else {
	die "Script only supports VMware VIMA 1.0.0 and vMA 4.x.x+\n";
}

&log("info", "============================== ghettoVCBg2 LOG START ==============================");
$semCopyTaskStart->up; # now CopyTask can do loging

if($vmlist) {
	&processFile($vmlist);
}

if(!defined($configDir)) {
        &log("info", "CONFIG - BACKUP_LOG_OUTPUT = " . $backup_log_output);
        &log("info", "CONFIG - VM_BACKUP_DATASTORE = " . $VM_BACKUP_DATASTORE);
        &log("info", "CONFIG - VM_BACKUP_DIRECTORY = " . $VM_BACKUP_DIRECTORY);
        &log("info", "CONFIG - DISK_BACKUP_FORMAT = " . $DISK_BACKUP_FORMAT);
        &log("info", "CONFIG - ADAPTER_FORMAT = " . $ADAPTER_FORMAT);
        my $powerDowntext = ($POWER_VM_DOWN_BEFORE_BACKUP ? "YES" : "NO");
        &log("info", "CONFIG - POWER_VM_DOWN_BEFORE_BACKUP = " . $powerDowntext);
        my $memtext = ($VM_SNAPSHOT_MEMORY ? "YES" : "NO");
        &log("info", "CONFIG - VM_SNAPSHOT_MEMORY = " . $memtext);
        my $quitext = ($VM_SNAPSHOT_QUIESCE ? "YES" : "NO");
        &log("info", "CONFIG - VM_SNAPSHOT_QUIESCE = ". $quitext);
        &log("info", "CONFIG - VM_BACKUP_DIR_NAMING_CONVENTION = " . $VM_BACKUP_DIR_NAMING_CONVENTION);
	&log("info", "CONFIG - VM_VMDK_FILES = " . $VM_VMDK_FILES . "\n"); 
}

foreach my $vima_host (@vima_targets) {
	$host = $vima_host;

	# login using fastpass
	eval {
		if($vima_ver eq "1.0.0" || $vima_ver eq "4.0.0") {
			&log("debug", "Main: Login by vi-fastpass to: " . $host);
			VIFPLib::login_by_fastpass($host);
		} elsif($vima_ver eq "4.1.0") {
			$host = $vima_host->name();
			&log("debug", "Main: Login by vi-fastpass to: " . $host);
			$vima_host->login();
		}
	};
	if(!$@) {
		#validate ESX/ESXi host
		$content = Vim::get_service_content();
		$host_type = $content->about->apiType;

		my $licMgr = Vim::get_view(mo_ref => $content->licenseManager);
		my $licenses = $licMgr->licenses;
		my $isRunningFree = 0;
		foreach(@$licenses) {
			if($_->editionKey eq 'esxBasic') {
				$isRunningFree = 1;
			}
		}
	
		if($host_type eq 'HostAgent' && !$isRunningFree) {
			$host_view  = Vim::find_entity_view(view_type => 'HostSystem');

        		if (!$host_view) {
				&log("warn", "ESX/ESXi host was not found");
		        } else {
				if($host_view->runtime->connectionState->val ne "connected") {
                	        	&log("warn", "ESX/ESXi is either disconnected or not responding, skipping");
				} else {
					my ($viuser,$vifplib);
					if($vima_ver eq "1.0.0" || $vima_ver eq "4.0.0") {
						$viuser = vifplib_perl::CreateVIUserInfo();
						$vifplib = vifplib_perl::CreateVIFPLib();
						eval { $vifplib->QueryTarget($host, $viuser); };
						if(!$@) {
							$host_username = $viuser->GetUsername();
							$host_password = $viuser->GetPassword();
						}
					} elsif($vima_ver eq "4.1.0") {
						$host_username = $vima_host->username();
						$host_password = $vima_host->password(); 
					}
        	    			if($vmlist) {
						&backUpVMs(@vm_backup_list);
					}
				}
			}
		} 
		if($host_type eq 'HostAgent' && $isRunningFree eq 1) { &log("warn", "$host is using free license & can't support VM backups!"); }
		&log("debug", "Main: Disconnect from: ". $host . "\n");
		Util::disconnect();
	} else {
		&log("warn", "Unable to login to: ". $host . " - maybe offline or unreachable - skipping\n");
	}
}

getFinalList(@vm_backup_list);
&log("debug", "Main: Calling final clean up");
&cleanUp();
&log("info","============================== ghettoVCBg2 LOG END ==============================\n\n");
# End main

if($SEND_MAIL eq "yes") {
	&sendMail();
}

########################
# HELPER FUNCTIONS
########################

sub sendMail {
        my $smtp = Net::SMTP->new($EMAIL_HOST ,Hello => $EMAIL_DOMAIN,Timeout => 30,);

        unless($smtp) {
                die "Error: Unable to setup connection with email server: \"" . $EMAIL_HOST . "\"!\n";
        }

        $smtp->mail($EMAIL_FROM);
        $smtp->to($EMAIL_TO);

        $smtp->data();
        $smtp->datasend('From: '.$EMAIL_FROM."\n");
        $smtp->datasend('To: '.$EMAIL_TO."\n");
        $smtp->datasend('Subject: ghettoVCBg2 Completed'.timeStamp('MDYHMS')."\n");
        $smtp->datasend("\n");

        open (HANDLE, $backup_log_output) or die(timeStamp('MDYHMS'), "ERROR: Can not locate log \"$backup_log_output\" !\n");
        my @lines = <HANDLE>;
        close(HANDLE);
        foreach my $line (@lines) {
                $smtp->datasend($line);
        }

        $smtp->dataend();
        $smtp->quit;

        `/bin/rm -f $backup_log_output`;
}

sub cleanUp {
	&log("debug", "cleanUP: Thread clean up starting ...");

	#only if Task was never started
	if($copyThreadStatus eq "wait") {
		&log("debug", "cleanUp: CopyTask was never started, send copyTaskStart");
		$semCopyTaskStart->up;
	}
	
	&log("debug", "cleanUp: Send exit to copyThread");
        $copyThreadStatus= "exit"; # send exit to copyThread
        $semWaitCopy->up;                  # wakeup
	eval {
	        $thr->join;                # wait for cleanup copyThread
		&log("debug", "cleanUp: Join passed");
	};
	if($@) { &log("warn", "cleanUp: ". $@ ); }
}


########################
# Copy Thread
########################
sub copyTask { 
	$semCopyTaskStart->down; # start, when main is ready
	&log("debug", "copyTask: Task START");
	do{
		&log("debug", "copyTask: waiting for next job and sleep ...");
		$semWaitCopy->down;	 # sleep

		&log("debug", "copyTask: Wake up and follow the white rabbit, with status: " .$copyThreadStatus );		
	
		if ($copyThreadStatus eq "doCopy"){
			&log("debug", "CopyThread: Start backing up VMDK(s) ...");
			eval {
				my $vmkfstools_cpy = `$copyCmd` ;
                                &log("debug", "copyTask: send copySuccess message ...");
				$copyThreadStatus= "copySuccess";
			} or do {	
				&log("error", "CopyTask: ". $@ );
				&log("error", "CopyTask: Cmd " .$copyCmd);
				$copyThreadStatus= "copyFail";
			}
		}
			
	} while ($copyThreadStatus ne "exit");
	&log("debug", "copyTask: die ...");
}

sub reConfigToBackupDirParameter {
	my ($vm_name) =  @_;
	
	$VM_VMDK_FILES = "all";
	
		
	my @goodparam = qw(VM_BACKUP_DATASTORE VM_BACKUP_DIRECTORY VM_BACKUP_ROTATION_COUNT DISK_BACKUP_FORMAT ADAPTER_FORMAT POWER_VM_DOWN_BEFORE_BACKUP LOG_LEVEL VM_SNAPSHOT_MEMORY VM_SNAPSHOT_QUIESCE VM_VMDK_FILES);

	my $file = "$configDir/$vm_name";
	if(-e $file && $success_backups{$vm_name} ne -1 && $success_backups{$vm_name} ne 1) {
		my %config;
		open(CONFIG, "$file") || &log("error", "Couldn't open the $file!");
		while (<CONFIG>) {
			chomp;
			s/#.*//; # Remove comments
			s/^\s+//; # Remove opening whitespace
			s/\s+$//;  # Remove closing whitespace
			next unless length;
			my ($key, $value) = split(/\s*=\s*/, $_, 2);
			if( grep $key eq $_,  @goodparam ) {
				$value =~ s/"//g;
				$config{$key} = $value;
			}
		}
		close(CONFIG);	
		
		&log("debug", "reConfigureBackupParams: VM - " . $vm_name);

		#reconfigure variables
		$LOG_LEVEL = $config{LOG_LEVEL};
		$LOGLEVEL = $loglevel{$LOG_LEVEL};
				
		$VM_BACKUP_DATASTORE = $config{VM_BACKUP_DATASTORE};
		$VM_BACKUP_DIRECTORY = $config{VM_BACKUP_DIRECTORY};
		$VM_BACKUP_ROTATION_COUNT = $config{VM_BACKUP_ROTATION_COUNT};
		$DISK_BACKUP_FORMAT = $config{DISK_BACKUP_FORMAT};
		$ADAPTER_FORMAT = $config{ADAPTER_FORMAT};
		$POWER_VM_DOWN_BEFORE_BACKUP = $config{POWER_VM_DOWN_BEFORE_BACKUP};
		$VM_SNAPSHOT_MEMORY = $config{VM_SNAPSHOT_MEMORY};
		$VM_SNAPSHOT_QUIESCE = $config{VM_SNAPSHOT_QUIESCE};
		$VM_VMDK_FILES = $config{VM_VMDK_FILES};
	
	} elsif($success_backups{$vm_name} ne -1 && $success_backups{$vm_name} ne 1) {
		$success_backups{$vm_name} = -1;
		&log("error", "ERROR - Unable to locate configuration file for VM: ". $vm_name . "\n");
	}
}

sub getFinalList {
	for my $key ( keys %success_backups ) {
		my $value = $success_backups{$key};
		if($value ne 1 && $value ne -1) {
			&log("error",  "getFinalList: ERROR - Unable to locate VM: ". $key . "\n");	
		}
	}
	
}

# Subroutine to process the input file
sub processFile {
	my ($vmlist) =  @_;
   	my $HANDLE;
	open (HANDLE, $vmlist) or die(timeStamp('MDYHMS'), "ERROR: Can not locate \"$vmlist\" input file!\n");
   	my @lines = <HANDLE>;
   	my @errorArray;
   	my $line_no = 0;

   	close(HANDLE);
   	foreach my $line (@lines) {
		$line_no++;
      		&TrimSpaces($line);

      		if($line) {
	        	if($line =~ /^\s*:|:\s*$/){
        	    		&log("error", "Error in Parsing File at line: $line_no");
	            		&log("info", "Continuing to the next line");
        	    		next;
         		}
		        my $vm = $line;
			&TrimSpaces($vm);

			#only update the list on the following cases:
			#If VM has not been found or backedup
			#If --config_dir was used but config file for VM was not found
			if (!exists $success_backups{$vm} || ($success_backups{$vm} ne -1 && $success_backups{$vm} ne 1) ) {
				push @vm_backup_list,$vm;
				$success_backups{$vm} = 0;
			}
      		}
   	}
}

sub TrimSpaces {
	foreach (@_) {
      	s/^\s+|\s*$//g
   	}
}

sub backUpVMs {
	my (@vm_backup_list) = @_;
	my $vm_backup_dir;
	my $snapshot_name;
	my $original_vm_state;
   	my $returnval;

	my $count = 0;
	foreach my $vm_name (@vm_backup_list) {
		if($success_backups{$vm_name} ne -1 && $success_backups{$vm_name} ne 1) {
			my $vm_view = Vim::find_entity_view(view_type => 'VirtualMachine',filter => {"config.name" => $vm_name});
			
			if(defined($vm_view)) {
				if(defined($configDir)) {
					reConfigToBackupDirParameter($vm_name)
				}

				#do not backup if snapshots have been found
				if($vm_view->snapshot) {
					&log("warn", "WARN - Snapshot found for ". $vm_name .", backup will not take place\n");
					$success_backups{$vm_name} = 1;
				} else {
					my $devices = $vm_view->config->hardware->device;
					foreach my $device (@$devices) {
						#verify device is virtual disk
	        				if ( ($device->isa('VirtualDisk')) ) {
							#verify thick/eagerzeroedthick
							if( ($device->backing->isa('VirtualDiskFlatVer1BackingInfo')) || ($device->backing->isa('VirtualDiskFlatVer2BackingInfo')) ) {
								#check for independent disks
								if( ($device->backing->diskMode eq 'independent_persistent') || ($device->backing->diskMode eq 'independent_nonpersistent') ) {
									$vmdk_type{$device->key} = "independent";
								} else {
									$vmdk_type{$device->key} = "flat";
								}
							}
							#verify 2gbsparse
							elsif ( ($device->backing->isa('VirtualDiskSparseVer1BackingInfo')) || ($device->backing->isa('VirtualDiskSparseVer2BackingInfo')) ) {
								#check for independent disks
								if( ($device->backing->diskMode eq 'independent_persistent') || ($device->backing->diskMode eq 'independent_nonpersistent') ) {
                                                                        $vmdk_type{$device->key} = "independent";
                                                                } else {
                                                                        $vmdk_type{$device->key} = "sparse";
								}
							}
							#verify RDM w/virtual compatiablity mode
							elsif ( ($device->backing->isa('VirtualDiskRawDiskMappingVer1BackingInfo')) && ($device->backing->compatibilityMode eq 'virtualMode') ) {
								#check for independent disks
								if( ($device->backing->diskMode eq 'independent_persistent') || ($device->backing->diskMode eq 'independent_nonpersistent') ) {
                                                                        $vmdk_type{$device->key} = "independent";
                                                                } else {
                                                                        $vmdk_type{$device->key} = "vrdm";
								}
							}
							elsif ( ($device->backing->isa('VirtualDiskRawDiskMappingVer1BackingInfo')) && ($device->backing->compatibilityMode eq 'physicalMode') ) {
								$vmdk_type{$device->key} = "prdm";
							}
						}
					}
					my $vmx_config = $vm_view->config->files->vmPathName;
					$vm_backup_dir = "[$VM_BACKUP_DATASTORE] $VM_BACKUP_DIRECTORY/$vm_name/$vm_name\-$VM_BACKUP_DIR_NAMING_CONVENTION";
					my $vmx_file = $vm_view->config->files->vmPathName;
	                               	($vmx_file) = ($vmx_file =~ m|.*/(.*)|);	
					my ($vm_datastore) = ($vmx_config=~ /\[([^]]+)/);
					
					if(defined($configDir)) {
						&log("info", "CONFIG - USING CONFIGURATION FILE = " . $vm_name);
                                		&log("info", "CONFIG - BACKUP_LOG_OUTPUT = " . $backup_log_output);
                        	                &log("info", "CONFIG - VM_BACKUP_DATASTORE = " . $VM_BACKUP_DATASTORE);
                	                        &log("info", "CONFIG - VM_BACKUP_DIRECTORY = " . $VM_BACKUP_DIRECTORY);
        	                                &log("info", "CONFIG - DISK_BACKUP_FORMAT = " . $DISK_BACKUP_FORMAT);
	                                        &log("info", "CONFIG - ADAPTER_FORMAT = " . $ADAPTER_FORMAT);
                                        	my $powerDowntext = ($POWER_VM_DOWN_BEFORE_BACKUP ? "YES" : "NO");
                                                &log("info", "CONFIG - POWER_VM_DOWN_BEFORE_BACKUP = " . $powerDowntext);
                                        	my $memtext = ($VM_SNAPSHOT_MEMORY ? "YES" : "NO");
                        	                &log("info", "CONFIG - VM_SNAPSHOT_MEMORY = " . $memtext);
                	                        my $quitext = ($VM_SNAPSHOT_QUIESCE ? "YES" : "NO");
                                	        &log("info", "CONFIG - VM_SNAPSHOT_QUIESCE = " . $quitext);
        	                                &log("info", "CONFIG - VM_BACKUP_DIR_NAMING_CONVENTION = " . $VM_BACKUP_DIR_NAMING_CONVENTION);
	                                        &log("info", "CONFIG - VM_VMDK_FILES = " . $VM_VMDK_FILES . "\n");	
					}

					if($enable_dryrun eq 1) {
						my $licMgr = Vim::get_view(mo_ref => $content->licenseManager);
					        my $licenses = $licMgr->licenses;
					        my $licenseType = "";
					        foreach(@$licenses) {
				        		$licenseType .= $_->editionKey . " ";
					        }

						&log("info", "---------- DRYRUN DEBUG INFO " . $vm_name . " ----------");
						&log("info", "DEBUG - Host Build: ". $content->about->fullName);
						&log("info", "DEBUG - License: " . $licenseType);
						&log("info", "DEBUG - Host: ". $host);
						&log("info", "DEBUG - Virtual Machine: ". $vm_name);
						&log("info", "DEBUG - VM ConfigPath: ". $vmx_config); 
						&log("info", "DEBUG - VMX File: ". $vmx_file);
						&log("info", "DEBUG - BackupConfigPath: ". $vm_backup_dir ."/". $vmx_file);
						&log("info", "DEBUG - BackupPath: ". $vm_backup_dir);
						&log("info", "DEBUG - VM Datastore: ". $vm_datastore);
						&log("info", "DEBUG - VMDK(s):");
						my $vm_disks = $vm_view->layout->disk;
						foreach(@$vm_disks) {
							my $disk_files = $_->diskFile;
							foreach(@$disk_files) {
								&log("info", "DEBUG - ". $_);
							}
						}
						$success_backups{$vm_name} = 1;
						&log("info", "---------- DRYRUN DEBUG INFO " . $vm_name . " ----------\n");
					} else {

						#####################
                        			# CREATE BACKUP DIR
						#####################
						&log("info", "Initiate backup for ". $vm_name ." found on ". $host);

						my $dir_result = `$vifs_cmd --server "$host" --username "$host_username" --password "$host_password" --mkdir "[$VM_BACKUP_DATASTORE] $VM_BACKUP_DIRECTORY"  2>&1`;
	                           		$dir_result = `$vifs_cmd --server "$host" --username "$host_username" --password "$host_password" --mkdir "[$VM_BACKUP_DATASTORE] $VM_BACKUP_DIRECTORY/$vm_name"  2>&1`;
	                           		$dir_result = `$vifs_cmd --server "$host" --username "$host_username" --password "$host_password" --mkdir "[$VM_BACKUP_DATASTORE] $VM_BACKUP_DIRECTORY/$vm_name/$vm_name\-$VM_BACKUP_DIR_NAMING_CONVENTION" 2>&1`;

						#####################
						# COPY VMX FILE
						#####################
						my $vmx_copy =  `$vifs_cmd --server "$host" --username "$host_username" --password "$host_password" --copy "$vmx_config" "$vm_backup_dir/$vmx_file" 2>&1`;
							
						#####################
						# GET STATE
						#####################
						$original_vm_state = $vm_view->runtime->powerState->val;
						&log("debug", $vm_name ." original powerState: ". $original_vm_state);
		
						#####################
	                        		# POWER OFF IF SET
						#####################
						my $returnStatus="OK";
						if( ($POWER_VM_DOWN_BEFORE_BACKUP eq 1) && ($original_vm_state eq 'poweredOn')  ) {
							$returnStatus = &shutdownVM($vm_view,$vm_name);
						} elsif( ($original_vm_state eq 'poweredOn') || ($original_vm_state eq 'suspended') ) {
							#####################
							# CREATE SNAPSHOT 
							#####################
							$snapshot_name = "ghettoVCBg2-snapshot-".timeStamp('YMD');
							$returnStatus= &create_snapshot($vm_view,$snapshot_name,$vm_name,$VM_SNAPSHOT_MEMORY,$VM_SNAPSHOT_QUIESCE);
						}
							
						#####################
		                    		# BACKUP VMDK
						#####################
						if ($returnStatus eq "OK"){  # only if there is a snapshort or vm is powered off 
							my $vm_disks = $vm_view->layout->disk;
							my @num_disks_ref = @$vm_disks;
							my $num_disks = @num_disks_ref;
							&log("info", $vm_name ." has ". $num_disks ." VMDK(s)");
							&backupVMDK($vm_disks,$vm_datastore,$vm_backup_dir,$vm_view);

							#####################
			                    		# UPDATE VM VIEW
			                    		#####################
			                    		$vm_view->update_view_data();

		                        		#####################
		                        		# POWER ON VM IF SET
		                        		#####################
							if( ($POWER_VM_DOWN_BEFORE_BACKUP eq 1) && ($original_vm_state eq 'poweredOn') ) {
								&poweronVM($vm_view,$vm_name);
							} elsif( ($original_vm_state eq 'poweredOn') || ($original_vm_state eq 'suspended') ) {
								#####################
								# REMOVE SNAPSHOT
								#####################
								&remove_snapshot($vm_view,$snapshot_name,$vm_name);
							}

							#####################
							# CHECK ROTATION
							#####################
							&checkVMBackupRotation($vm_view,"[$VM_BACKUP_DATASTORE] $VM_BACKUP_DIRECTORY/$vm_name","[$VM_BACKUP_DATASTORE] $VM_BACKUP_DIRECTORY/$vm_name/$vm_name\-$VM_BACKUP_DIR_NAMING_CONVENTION",$vm_name,$vmx_file);
							
							&log("info",  "Backup completed for ". $vm_name ."!\n");
							$success_backups{$vm_name} = 1;
							%vmdk_type = ();
						} #end returnStatus
					}
				}
			}
		}
	}
	return $returnval;
}

sub poweronVM {
	my ($vm_view,$vm_name) = @_;
	eval {
	        $vm_view->PowerOnVM();
		my $continue = 1;
		while ($continue) {
			my $vm_state = $vm_view->runtime->powerState->val;
			if($vm_state eq 'poweredOn') {
				&log("debug", "Successfully powered back on ". $vm_name);
				$continue = 0;
			}
			sleep 2;
			$vm_view->update_view_data();
		}
	};
	if($@) {
		&log("error",  "FAULT ERROR: Unable to power back on ". $vm_name); 
	}
}

sub shutdownVM {
	my ($vm_view,$vm_name) = @_;
	my $status="OK";
	if($vm_view->summary->guest->toolsStatus->val eq 'toolsOk') {
		eval {
			$vm_view->ShutdownGuest();
			my $continue = 1;
			while($continue) {
				my $vm_state = $vm_view->runtime->powerState->val;
				if($vm_state eq 'poweredOff') {
					&log("debug", "Successfully shutdown ".$vm_name);
					$continue = 0;
				}
				sleep 2;
				$vm_view->update_view_data();
			}
		};
		if($@) { 
			&log("error",  "FAULT ERROR: ". $@ ); 
			$status="FAIL";
		}
	} else {
		eval {
			$vm_view->PowerOffVM();
			my $continue = 1;
			while ($continue) {
				my $vm_state = $vm_view->runtime->powerState->val;
				if($vm_state eq 'poweredOff') {
					&log("debug", "Hard power off, VMware Tools is not installed on ". $vm_name);
						$continue = 0;
					}
					sleep 2;
					$vm_view->update_view_data();
                	}
		};
		if($@) { 
			&log("error",  "FAULT ERROR: ". $@ ); 
			$status="FAIL";
		}
	}
	return $status;
}

sub checkVMBackupRotation {
        my ($vm_view, $BACKUP_DIR_PATH,$BACKUP_VM_NAMING_CONVENTION,$vm_name,$vmx_file) = @_;
	my @LIST_BACKUPS = `$vifs_cmd --server "$host" --username "$host_username" --password "$host_password" --dir "$BACKUP_DIR_PATH" 2>&1`;

	&log("debug", "checkVMBackupRotation: Starting ...");

        #default rotation if variable is not defined
        if(!defined($VM_BACKUP_ROTATION_COUNT)) {
                $VM_BACKUP_ROTATION_COUNT = "1";
        }

	chomp(@LIST_BACKUPS);

	foreach my $DIR (reverse(@LIST_BACKUPS)) {
		$DIR =~ s/\///g;
		#################################
		# VMware bug in vCLI vifs --dir
		# SR 1291801391
		#################################
		# tmp fix
		if($DIR !~ /^Parent Directory/ && $DIR !~ /^Content Listing/ && $DIR !~ /---------------/ && $DIR ne "") {
			my $NEW;
			my $mv_dir;
			my $TMP_DIR="$BACKUP_DIR_PATH/$DIR";
			my ($BAD, $TMP) = split('--', $TMP_DIR);
			if(!defined($TMP)) {
				$TMP = $TMP_DIR;
			}

			if($TMP eq $BACKUP_VM_NAMING_CONVENTION) {
				$NEW=$TMP."--1";
				$mv_dir = `$vifs_cmd --server "$host" --username "$host_username" --password "$host_password" --move "$TMP_DIR" "$NEW" 2>&1`;
			} elsif($TMP ge $VM_BACKUP_ROTATION_COUNT) {
				my $path = $TMP_DIR;

				my $fm = Vim::get_view (mo_ref => $content->{fileManager});
				eval {
					$fm->DeleteDatastoreFile(name => $path);
					&log("debug", "Purging ". $path ." due to rotation max");
				};
				if($@) { &log("debug", "Unable to purge ". $path ." due to rotation max");}
			} else {
				my ($BASE, $BAD) = split('--',$TMP_DIR);
				$NEW = $BASE."--".($TMP+1);
				$mv_dir = `$vifs_cmd --server "$host" --username "$host_username" --password "$host_password" --move "$TMP_DIR" "$NEW" 2>&1`;
			}
		}
	}
}

sub backupVMDK {
	my ($vm_disks,$vm_datastore,$vm_backup_dir, $vm_view) = @_;
	foreach(@$vm_disks) {
		my $disk_files = $_->diskFile;
		my $diskKey = $_->key;
		foreach(@$disk_files) {
			if( ($vmdk_type{$diskKey} ne 'prdm') && ($vmdk_type{$diskKey} ne 'independent') ) {
				my $curr_vmdk_path = $_;
				my ($tmp_vm_datastore) = ($curr_vmdk_path =~ /\[([^]]+)/);
				my ($tmp_vm_vmdk) = ($curr_vmdk_path =~ m|.*/(.*)|);
				my $vmdk_backup_destination;

				if($tmp_vm_datastore eq $vm_datastore) {
					$vmdk_backup_destination = $vm_backup_dir."/".$tmp_vm_vmdk;
				} else {
					$vmdk_backup_destination = $vm_backup_dir."/".$tmp_vm_datastore."/".$tmp_vm_vmdk;
					my $ds_mkdir = `$vifs_cmd --server "$host" --username "$host_username" --password "$host_password" --mkdir "$vm_backup_dir/$tmp_vm_datastore" 2>&1`;
				}

				my $isVMDKFound = &findVMDKFile($tmp_vm_vmdk, $VM_VMDK_FILES);
				
			        if ($VM_VMDK_FILES eq "all" || $isVMDKFound ){
					&log("debug", "backupVMDK: Backing up \"". $_ ."\" to \"". $vmdk_backup_destination ."\"");
						
					#$copyCmd is shared with copyThread
						
					#case for legacy VIMA 1.0
					if($vima_ver eq "1.0.0" && ($DISK_BACKUP_FORMAT eq 'zeroedthick' || $DISK_BACKUP_FORMAT eq 'eagezeroedthick')) {
						$copyCmd = $vmkfstools_cmd  ." --server \"". $host ."\" --username \"". $host_username ."\" --password \"". $host_password ."\" -i \"". $_ ."\" -a ". $ADAPTER_FORMAT ." -d \"".  $vmdk_backup_destination ."\" 2>&1";
					} else {
						#vMA 4.0.0 should have fixed the issue
						$copyCmd = $vmkfstools_cmd ." --server \"". $host ."\" --username \"". $host_username ."\" --password \"". $host_password ."\" -i \"". $_ ."\" -a ". $ADAPTER_FORMAT ." -d ". $DISK_BACKUP_FORMAT ." \"". $vmdk_backup_destination ."\" 2>&1";
					}

					if ($copyThreadStatus eq "exit") {
						&log("error", "backupVMDK: ERROR - copyThread not alive!");					
					} else {
						&log("debug", "backupVMDK: Signal copyThread to start");
						$copyThreadStatus= "doCopy"; # send start to copyThread
						$semWaitCopy->up;	 	     # wakeup

						my $elapsedTime=0;
						do {
							if ($elapsedTime % 15 == 0) {&log("debug", "backupVMDK: Backup progress: Elapsed time ". $elapsedTime ." min")};
							$vm_view->update_view_data();
							sleep(60);
							$elapsedTime++; 
						} until(($copyThreadStatus eq "copySuccess") || ($copyThreadStatus eq "copyFail") || ($copyThreadStatus eq "exit"));
				
						if ($copyThreadStatus eq "copySuccess") {
                                        		&log("debug", "backupVMDK: Successfully completed backup for ". $_  ." Elapsed time: ". $elapsedTime ." min");		   				     } else {
							&log("error", "backupVMDK: ERROR - Unable to backup VMDK: ". $_  ." Elapsed time: ". $elapsedTime ." min");
						}	
					}
				}	
			}
		}
	}
}

sub findVMDKFile {
	my ($searchFile, $list) = @_;
	my $isFound = 0;  #false
	
	my @vmdkFileList = split(/,/,$list);
	
	foreach my $file (@vmdkFileList) {
	
		#remove whitespace from the start and end 
		$file =~ s/^\s+//;
		$file =~ s/\s+$//;

		if ( $searchFile eq $file){ 
			$isFound = 1;
			&log("debug", "findVMDKFile: Found VMDK File: ".$file);
		}
	}
	return $isFound;				
}

# Create: Creates a snapshot for one or more VMs.
#===========================================================
sub create_snapshot {
	my ($vm_view, $snapshot_name, $vm_name, $mem, $qui) = @_;
	my $status = "OK";
      	eval {
		my $taskRef = $vm_view->CreateSnapshot_Task(name => $snapshot_name,
                description => 'Snapshot created for Virtual Machine '.$vm_view->name,
                memory => $mem,
                quiesce => $qui);
		&log("debug", "Creating Snapshot \"". $snapshot_name ."\" for ". $vm_name); 	

		my $task_view = Vim::get_view(mo_ref => $taskRef);
        	my $taskinfo = $task_view->info->state->val;
       		my $continue = 1;
        	while ($continue) {
                	my $info = $task_view->info;
                	if ($info->state->val eq 'success') {
                        	$continue = 0;
        	        } elsif ($info->state->val eq 'error') {
				$status="FAIL";
				$continue = 0;
                	}
			sleep 5;
                	$task_view->ViewBase::update_view_data();
	        }
	
	};
	if ($@) { 
		&log("error", "ERROR FAULT: ". $@); 
		$status="FAIL";
	}
	return $status;
}

# Remove: removes a named snapshot for one or more virtual machines.
# ==================================================================
sub remove_snapshot {
	my ($vm_view, $remove_snapshot, $vm_name) = @_;
	my $children = 0;
      	my $ref = undef;
      	my $nRefs = 0;

      	if(defined $vm_view->snapshot) {
        	($ref, $nRefs) = find_snapshot_name ($vm_view->snapshot->rootSnapshotList, $remove_snapshot);
      	}

      	if (defined $ref && $nRefs == 1) {
        	my $snapshot = Vim::get_view (mo_ref =>$ref->snapshot);
         	eval {
            		$snapshot->RemoveSnapshot (removeChildren => $children);
			&log("debug", "Removing Snapshot \"". $remove_snapshot ."\" for ". $vm_name);
         	};
         	if ($@) {
			&log("error", "ERROR FAULT: ". $@);
         	}
      	}
      	else {
		if ($nRefs > 1) {
			&log("warn", "WARNING: More than one snapshot exists with name \"". $remove_snapshot );
         	}
         	if($nRefs == 0 ) {
			&log("warn", "WARNING: Snapshot \"". $remove_snapshot ."\" not found");
         	}
      	}
}

#  Find a snapshot with the name
#  This either returns: The reference to the snapshot
#  0 if not found & 1 if it's a duplicate
#  Duplicacy check is required for rename, remove and revert operations
#  For these operation specified snapshot name must be unique
# ==================================================
sub find_snapshot_name {
   my ($tree, $name) = @_;
   my $ref = undef;
   my $count = 0;
   foreach my $node (@$tree) {
      if ($node->name eq $name) {
         $ref = $node;
         $count++;
      }
      my ($subRef, $subCount) = find_snapshot_name($node->childSnapshotList, $name);
      $count = $count + $subCount;
      $ref = $subRef if ($subCount);
   }
   return ($ref, $count);
}

sub timeStamp {
	my ($date_format) = @_;
	my %dttime = ();
        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	my $my_time;
	my $time_string;

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
		$time_string = $my_time." -- ";
	} elsif ($date_format eq 'YMD') {
		$my_time = "$dttime{year}-$dttime{mon}-$dttime{mday}";
		$time_string = $my_time;
	}
	return $time_string;
}

sub getStatus {
	my ($taskRef,$message) = @_;
	
	my $task_view = Vim::get_view(mo_ref => $taskRef);
	my $taskinfo = $task_view->info->state->val;
	my $continue = 1;
	while ($continue) {
        	my $info = $task_view->info;
        	if ($info->state->val eq 'success') {
			&log("debug", $message);
               		$continue = 0;
        	} elsif ($info->state->val eq 'error') {
               		my $soap_fault = SoapFault->new;
	   	        $soap_fault->name($info->error->fault);
               		$soap_fault->detail($info->error->fault);
               		$soap_fault->fault_string($info->error->localizedMessage);
			&log("error", "ERROR FAULT: ". $soap_fault);		
        	}
        	sleep 5;
        	$task_view->ViewBase::update_view_data();
	}
}

sub log {
	my($logLevel, $message) = @_;
	
	$semLog->down; 
	open(LOG,">>$backup_log_output");
	if ($LOGLEVEL <= $loglevel{$logLevel}) {
		print LOG "\t" . timeStamp('MDYHMS'), " ",$logLevel, ": ", $message,"\n";		
	}
	close(LOG);
	$semLog->up;
}

