#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://communities.vmware.com/docs/DOC-11708

use strict;
use File::Path;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;
use VMware::VIExt;

# define custom options for vm and target host
my %opts = (
	'vmclonelist' => {
      		type => "=s",
      		help => "VM Clone list",
      		required => 1,
   	},
	'basevm' => {
                type => "=s",
                help => "Name of the base VM to clone from",
                required => 1,
        },
	'loglevel' => {
                type => "=s",
                help => "Enable debugging [info|debug]",
                required => 0,
		default => 'info',
        },
	'logreport' => {
                type => "=s",
                help => "fullpath to log report (e.g. /tmp/ghettoCloneVM.log or C:\\ghettoCloneVM.log)",
		required => 0,
	}
);

# read and validate command-line parameters 
Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();
my $hosttype = &validateConnection('3.5.0','undef','HostAgent');

my ($host_view,$basevm_view,$vdm,$fm,$dc,$rp,$task_ref,$vmclonelist,$basevm,$loglevel,$logreport);
my ($basevm_vmx,@basevm_disks);
my @vmstoclone = ();
my %vmdk_name_change = ();

$vmclonelist = Opts::get_option("vmclonelist");
$basevm = Opts::get_option("basevm");
$loglevel = Opts::get_option("loglevel");
$logreport = Opts::get_option("logreport");

#######################################
# OS SPECIFIC PARAMS
#######################################
my ($clone_working_dir,$perl_bin_path);

#sel tmp path based on OS
if($^O =~ m/linux/) {
	$clone_working_dir = "/tmp/ghettoCloneVM";
	$perl_bin_path = "perl";
} elsif($^O =~ m/MS/) {
	$clone_working_dir = "C:\\ghettoCloneVM";
	$perl_bin_path = "perl";
}

# log level
my %log_level=(
        "debug"   => 1,
        "info"    => 2,
);

my $LOGLEVEL = $log_level{$loglevel};

$host_view = Vim::find_entity_view(view_type => 'HostSystem');
$basevm_view = Vim::find_entity_view(view_type => 'VirtualMachine', filter => {"name" => $basevm});
$dc = Vim::find_entity_view(view_type => 'Datacenter',filter => {name => 'ha-datacenter'});
$rp = Vim::find_entity_view(view_type => 'ResourcePool',filter => {name => 'Resources'});
$vdm = VIExt::get_virtual_disk_manager();
$fm = $fm = VIExt::get_file_manager();

&verifyBaseVM();
&readFile($vmclonelist);
&cloneVMs();

Util::disconnect();

#####################
# HELPER FUNCTIONS 
#####################

sub cloneVMs {
	if(! -d $clone_working_dir) {
        	mkdir($clone_working_dir, 0755)|| print $!;
	}

	$basevm_vmx = $basevm_view->config->files->vmPathName;
	my $disks = $basevm_view->layout->disk;

	foreach(@vmstoclone) {
        	my ($vmclone_name,$vmclone_diskformat,$vmclone_adaptertype,$vmclone_datastore) = split(' ',$_);
		my $vmclone_folder = $vmclone_name;
		my $vmclone_vmx = $vmclone_name . ".vmx";

		&log("info","Start cloning of $vmclone_name ...");
	
		if($vmclone_diskformat eq 'default') { $vmclone_diskformat = undef; }
		if($vmclone_adaptertype eq 'default') { $vmclone_adaptertype = undef; }

		my $created_folder = 0;
		my $vmdk_count = 0;
		foreach(@$disks) {
			my $diskFiles = $_->diskFile;
			my ($vmclone_vmdk_name,$datastore,$vmclone_datastore_path);
			foreach(@$diskFiles) {
				my ($vmbase_ds,$vmbase_vmdk) = split(']',$_);
				if($vmclone_datastore && $vmclone_datastore ne 'default') {
					$datastore = $vmclone_datastore;  
				} else {
					$datastore = $vmbase_ds;
					$datastore =~ s/\[//;
				}

				if($created_folder eq 0) {
					createFolder($fm,$datastore,$vmclone_folder);
					$created_folder = 1;
				}

				$vmclone_vmdk_name = $vmclone_name . "_" . $vmdk_count . ".vmdk";

				if($vmclone_datastore eq 'default') { 
					$vmclone_datastore_path = $vmbase_ds . "] " . $vmclone_folder . "/" . $vmclone_vmdk_name; 
					$vmclone_datastore = $vmbase_ds;
					$vmclone_datastore =~ s/\[//;
				} else {
					$vmclone_datastore_path = "[" . $vmclone_datastore . "] " . $vmclone_folder . "/" . $vmclone_vmdk_name;
				}
				$vmbase_vmdk =~ s/.*\///g;
				$vmdk_name_change{$vmbase_vmdk} = $vmclone_vmdk_name;
				clone_disk($vdm, $_, $vmclone_datastore_path, $vmclone_diskformat, $vmclone_adaptertype);
				$vmdk_count++;
			}
		}
		my $local_download_path;
		if($^O =~ m/linux/) {
			$local_download_path = $clone_working_dir . "/" . $vmclone_vmx;
		} elsif($^O =~ m/MS/) {
			$local_download_path = $clone_working_dir . "\\" . $vmclone_vmx;
		}

		my $remote_upload_path = "[" . $vmclone_datastore . "] " . $vmclone_folder . "/" . $vmclone_vmx;

		&log("debug","Downloading VMX configuration \"$basevm_vmx\" to \"$local_download_path\"");
		downloadVMX($basevm_vmx,$local_download_path);

		&log("debug","Modifying VMX configuration \"$local_download_path\"");
		modifyVMX($local_download_path);

		&log("debug","Uploading VMX configuration \"$local_download_path\" to \"$remote_upload_path\"");
		uploadVMX($local_download_path,$remote_upload_path);

		registerVM($remote_upload_path,$vmclone_name,$dc,$rp);

		my $newvm_view = Vim::find_entity_view(view_type => 'VirtualMachine',filter => {name => $vmclone_name});

		&log("debug","Updating annotation field for VM");
		addAnnotation($newvm_view);
		&log("info","Completed cloning for $vmclone_name ...\n");
	}

	rmtree($clone_working_dir);
}

sub verifyBaseVM {
	unless($basevm_view) {
        	Util::disconnect();
	        &log("info","Error: Unable to locate base VM \"$basevm\"!");
        	exit 1;
	}
	if($basevm_view->runtime->powerState->val ne 'poweredOff') {
		Util::disconnect();
                &log("info","Error: VM \"$basevm\" is still powered On! To clone, you will need to power off the VM!");
                exit 1;
	}
}

# Subroutine to process the input file
sub readFile {
        my ($filename) =  @_;

	open( FILE, "< $filename" ) or die "Can't open $filename : $!";
	while( <FILE> ) {
		s/#.*//;
		next if /^(\s)*$/;
		chomp;
		push @vmstoclone, $_;
	}
	close FILE;
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
		&log("info","This script requires your ESX(i) host to be greater than $host_version");
                exit 1;
        }

        ########################
        # CHECK HOST LICENSE
        ########################
        my $licenses = $licMgr->licenses;
        foreach(@$licenses) {
                if($_->editionKey eq 'esxBasic' && $host_license eq 'licensed') {
                        Util::disconnect();
			&log("info","This script requires your ESX(i) be licensed, the free version will not allow you to perform any write operations!\n");
                        exit 1;
                }
        }

        ########################
        # CHECK HOST TYPE
        ########################
        if($service_content->about->apiType ne $host_type && $host_type ne 'both') {
                Util::disconnect();
		if($host_type eq 'HostAgent') {
			&log("info","This script needs to be executed against individual ESX(i) host");
		} else {
			&log("info","This script needs to be executed against vCenter host");
		}
                exit 1
        }

        return $service_content->about->apiType;
}

sub addAnnotation {
	my ($vm) = @_;
	my $annotation = $vm->name . " cloned from " . $basevm_view->name . " using ghettoCloneVM.pl";

	eval {
                my $spec = VirtualMachineConfigSpec->new(annotation => $annotation);
                my $task = $vm->ReconfigVM_Task(spec => $spec);
                my $msg = "Sucessfully updated annotation for \"" . $vm->name . "\"!";
                &getStatus($task,$msg);
        };
	if($@) {
                &log("info",$@."\n");
        }
}

sub registerVM {
	my ($vm,$name,$dc,$rp) = @_;
	my $vmFolder = Vim::get_view(mo_ref => $dc->vmFolder);

	eval {
		&log("info","Registering \"$vm\" as \"$name\"");
		$task_ref = $vmFolder->RegisterVM_Task(path => $vm, name => $name, asTemplate => 'false', pool => $rp);	
		my $message = "Successfully registered VM";
      		&getStatus($task_ref,$message);
	};
	if($@) {
		&log("info",$@."\n");
	}
}

sub copyVMX {
	my ($fm, $source_path, $target_path, $dcRef) = @_;

   	eval {
		&log("info","Cloning disk \"$source_path\" to \"$target_path\"");
        	$task_ref = $fm->CopyDatastoreFile_Task(sourceName => $source_path,
            		sourceDatacenter => $dcRef,
            		destinationName => $target_path,
        	    	force => 0);
		my $message = "Successfully copied vmx\n";
      		&getStatus($task_ref,$message);
   	};
   	if ($@) {
	      	&log("info","Unable to copy " . $source_path . " to " .  $target_path . ($@->fault_string));
   	}
}

sub createFolder {
	my ($fm, $ds, $dir) = @_;
   	my $remote_path = "[$ds] $dir";

      	eval {
        	$fm->MakeDirectory(name => $remote_path);
		&log("debug","Create remote directory \"$remote_path\" successfully");
      	};
      	if ($@) {
		&log("info","Unable to create remote directory \"$remote_path\"");
      	}
}

sub modifyVMX {
	my ($local_source) = @_;

	for my $source_vmdk ( keys %vmdk_name_change ) {
        	my $destination_vmdk = $vmdk_name_change{$source_vmdk};
		#update new VMDK name
		`$perl_bin_path -p -i.bak -e "s/$source_vmdk/$destination_vmdk/g" $local_source`;

		#remove uuid.bios,uuid.location,vc.uuid
		`$perl_bin_path -p -i.bak -e "s/uuid.bios.*//g" $local_source`;
		`$perl_bin_path -p -i.bak -e "s/uuid.location.*//g" $local_source`;
		`$perl_bin_path -p -i.bak -e "s/vc.uuid.*//g" $local_source`;

		#remove eth0 MAC to new one would be generated
    	}
	%vmdk_name_change = ();
}

sub uploadVMX {
	my ($local_source, $remote_target) = @_;
   	my ($mode, $dc, $ds, $filepath) = VIExt::parse_remote_path($remote_target);
   	# bug 322577
   	if (defined $local_source  and -d $local_source) {
      		&log("info","Error: File to be uploaded cannot be a folder");
   	}

   	# bug 266936
   	unless (-e $local_source) {
      		&log("info","Error: File $local_source does not exist");
   	}

   	my $resp = VIExt::http_put_file($mode, $local_source, $filepath, $ds, $dc);
   	# bug 301206
   	if ($resp && $resp->is_success) {
      		&log("debug","Uploaded file $local_source to $filepath successfully");
   	} else {
      		&log("info","Error: File $local_source can not be uploaded to $filepath");
   	}
}

# bug 322577
sub downloadVMX {
	my ($remote_source, $local_target) = @_;
   	my ($mode, $dc, $ds, $filepath) = VIExt::parse_remote_path($remote_source);
   	if (defined $local_target and -d $local_target) {
      		my $local_filename = $filepath;
      		$local_filename =~ s@^.*/([^/]*)$@$1@;
      		$local_target .= "/" . $local_filename;
   	}
   	my $resp = VIExt::http_get_file($mode, $filepath, $ds, $dc, $local_target);
   	# bug 301206, 266936
   	if (defined $resp and $resp->is_success) {
      		&log("debug","Downloaded file to $local_target successfully");
   	} else {
      		&log("info","Error: File can not be downloaded to $local_target");
   	}
}

sub clone_disk {
	my ($vdm, $src_disk, $target_disk, $disk_type, $adapter_type) = @_;

	&log("debug","\tSOURCE      DISK: \"$src_disk\"");
	&log("debug","\tDESTINATION DISK: \"$target_disk\"");
	&log("debug","\tDISK        TYPE: \"$disk_type\"");
	&log("debug","\tADAPTER     TYPE: \"$adapter_type\"");

   	$disk_type = "zeroedthick" unless defined($disk_type);
   	$adapter_type = "busLogic" unless defined($adapter_type);

   	my $spec = new FileBackedVirtualDiskSpec();
   	$spec->{capacityKb} = 10000; # dummy

   	# use source's format if unset
   	$spec->{diskType} = convert_disk_format($disk_type);
   	$spec->{adapterType} = convert_adapter_string($adapter_type);

   	eval {
      		&log("info","Cloning disk \"$src_disk\" to \"$target_disk\"");
      		$task_ref = $vdm->CopyVirtualDisk_Task(sourceName => $src_disk,  sourceDatacenter => undef,
                            destName => $target_disk, destDatacenter => undef,
                            destSpec => $spec, force => 1);
      		my $message = "Successfully cloned disk";
      		&getStatus($task_ref,$message);
   	};
   	if ($@) {
      		&log("info","Unable to clone virtual disk : " . ($@->fault_string));
   	}
}

sub convert_adapter_string {
	my $adapterType = shift;
   	if (defined($adapterType)) {
      		if ($adapterType =~ /^lsilogic$/i) {
         		return "lsiLogic";
      		} elsif ($adapterType =~ /^buslogic$/i) {
         		return "busLogic";
      		} elsif ($adapterType =~ /^ide$/i) {
         		return "ide";
      		}
   	} else {
      		return undef;
   	}
}

sub convert_disk_format {
	my $disk_format = shift;
   	if (defined($disk_format)) {
      		if ($disk_format =~ /^2gbsparse$/i) {
        		 return "sparse2Gb";
      		} elsif ($disk_format =~ /^zeroedthick$/i) {
         		return "preallocated";
      		} elsif ($disk_format =~ /^eagerzeroedthick$/i) {
         		return "eagerZeroedThick";
      		} else {
        		return $disk_format;
      		}
   	} else {
      		return undef;
   	}
}

sub getStatus {
        my ($taskRef,$message) = @_;

        my $task_view = Vim::get_view(mo_ref => $taskRef);
        my $taskinfo = $task_view->info->state->val;
        my $continue = 1;
        while ($continue) {
                my $info = $task_view->info;
                if ($info->state->val eq 'success') {
			&log("debug",$message);
                        return $info->result;
                        $continue = 0;
                } elsif ($info->state->val eq 'error') {
                        my $soap_fault = SoapFault->new;
                        $soap_fault->name($info->error->fault);
                        $soap_fault->detail($info->error->fault);
                        $soap_fault->fault_string($info->error->localizedMessage);
			Util::disconnect();
                        &log("info","$soap_fault");
			exit 1;
                }
                sleep 5;
                $task_view->ViewBase::update_view_data();
        }
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

sub log {
        my($logLevel, $message) = @_;

	if($LOGLEVEL <= $log_level{$logLevel}) {	
		if($logreport) {
			open(LOG,">>$logreport");
			print LOG "\t" . timeStamp('MDYHMS'), " ",$logLevel, ": ", $message,"\n";
			close(LOG);			
		} else {
                	print "\t" . timeStamp('MDYHMS'), " ",$logLevel, ": ", $message,"\n";
		}
	}
}
