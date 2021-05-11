#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://communities.vmware.com/docs/DOC-11593

use strict;
use warnings;
use Term::ANSIColor;
use VMware::VILib;
use VMware::VIRuntime;

$SIG{__DIE__} = sub{Util::disconnect();};

my %opts = (
   datacenter => {
      type => "=s",
      help => "Datacenter to search for VM(s) .vmx files to register",
      required => 0,
   },
   cluster => {
      type => "=s",
      help => "Cluster to search for VM(s) .vmx files to register",
      required => 0,
   },
   datastore => {
      type => "=s",
      help => "Datastore(s) to search for VM(s) .vmx files to register",
      required => 0,
   },
   findtemplates => {
      type => "=s",
      help => "Search for VM Templates [0|1]",
      required => 0,
      default => 0,
   },
);

# validate options, and connect to the server
Opts::add_options(%opts);

# validate options, and connect to the server
Opts::parse();
Opts::validate();
Util::connect();

my $content = Vim::get_service_content();
my $hostType = $content->about->apiType;

my $datacenter = Opts::get_option('datacenter');
my $cluster = Opts::get_option('cluster');
my $findtemplates = Opts::get_option('findtemplates');
my $datastore = Opts::get_option('datastore');
my $searchSpecificDatastores = "false";
my $isStandalone = 0;

my ($datastores,$dc_view,$cluster_view,$host_view);

my @datastore_search;
if($datastore) {
	@datastore_search = split(',',$datastore);
	if(@datastore_search) {
		$searchSpecificDatastores = "yes";
	}
}

if($hostType eq 'VirtualCenter') {
        if($datacenter) {
		$dc_view = Vim::find_entity_view(view_type => 'Datacenter', filter => {'name' => $datacenter});
		unless($dc_view) {
			Util::disconnect();
			die "Unable to locate Datacenter: \"$datacenter\"!\n";
		}
		$datastores = Vim::get_views(mo_ref_array => $dc_view->datastore);
		&goFindVMXs($datastores);
        } elsif($cluster) {
		$cluster_view = Vim::find_entity_view(view_type => 'ClusterComputeResource', filter => {'name' => $cluster});
		unless($cluster_view) {
                        Util::disconnect();
                        die "Unable to locate Cluster: \"$cluster\"!\n";
                }
		$datastores = Vim::get_views(mo_ref_array => $cluster_view->datastore);
		&goFindVMXs($datastores);
        } else {
                Util::disconnect();
                die "When specifying vCenter server, you must use either --datacenter or --cluster with valid input!\n";
        }
} else {
        $host_view = Vim::find_entity_view(view_type => 'HostSystem');
	$isStandalone = 1;
	$datastores = Vim::get_views(mo_ref_array => $host_view->datastore);
	&goFindVMXs($datastores);
}

Util::disconnect();

sub goFindVMXs {
	my ($datastores) = @_;
	my @hosts = ();
        foreach(@$datastores) {
        	if($_->summary->accessible) {
			my $good = &verifyDatastore($_);
			if($good eq 'yes') {
				my $datastoreFolder = Vim::get_view(mo_ref => $_->parent);
				my $dc = Vim::get_view(mo_ref => $datastoreFolder->parent);
				my $vmFolder = Vim::get_view(mo_ref => $dc->vmFolder);

                		my $hostMounts = $_->host;
                       		my %uniquehosts = ();
				my %uniquevms = ();
				my $datastoreName = $_->name;
                        	foreach(@$hostMounts) {
                        		my $host = Vim::get_view(mo_ref => $_->key);
                                	my $hostname = $host->name;
                                	if(!$uniquehosts{$hostname}) {
                                		$uniquehosts{$hostname} = "yes";
                                        	push @hosts,$host;
                                	}
                        	}
                        	my $range = scalar(@hosts);

                        	#search ds
                        	my $ds_path = "[" . $datastoreName . "]";
				my $file_query = FileQueryFlags->new(fileOwner => 0, fileSize => 0,fileType => 1,modification => 0);
				my @pattern = ();
				if($findtemplates eq 1) {
					@pattern = ("*.vmx","*.vmtx");
				} else {
					@pattern = ("*.vmx");
				}
                        	my $searchSpec = HostDatastoreBrowserSearchSpec->new(details => $file_query, matchPattern => \@pattern);
                        	my $browser = Vim::get_view(mo_ref => $_->browser);
                        	my $search_res = $browser->SearchDatastoreSubFolders(datastorePath => $ds_path,searchSpec => $searchSpec);

                        	if ($search_res) {
                        		foreach my $result (@$search_res) {
                                		my $folderPath = $result->folderPath;
                                		my $files = $result->file;
                                        	if ($files) {
                                        		foreach my $file (@$files) {
								my ($vmname,$vmx_file,$vmx_path,$filetype);
								$vmx_file = $file->path;
								$vmname = $vmx_file;
								if(!$uniquehosts{$vmx_file}) {
			                                        	$uniquevms{$vmx_file} = "yes";
                                                        		$vmx_path = $folderPath . "/" . $vmx_file;
										
									my $hostToUse;
									if($isStandalone eq 0) {
										my $i = rand($range);
                                                                		$hostToUse = $hosts[$i];
									} else { 
										$hostToUse = $host_view; 
									}
									my $hostname = $hostToUse->name;
                                                                	my $parent = Vim::get_view(mo_ref => $hostToUse->parent);
                                                                	my $rp = Vim::get_view(mo_ref => $parent->resourcePool);

									my $isTemplate = 'false';
									my $templateString = '';
									if(ref($file) eq 'TemplateConfigFileInfo') {
										$vmname =~ s/.vmtx//;
										$isTemplate = 'true';
										$templateString = " Template";
										$rp = undef;
									} else {
										$vmname =~ s/.vmx//;
										$hostToUse = undef;
									}
									my $taskRef;
									$taskRef = $vmFolder->RegisterVM_Task(name => $vmname, path => $vmx_path, asTemplate => $isTemplate, pool => $rp, host => $hostToUse);
                	                                        	print "Registering VM" . $templateString . ": " . color("magenta") . $vmname . color("reset") ." on Host: " . color("yellow") . $hostname . color("reset") . " from Datastore: " . color("green") . $datastoreName . color("reset") . " ...\n";
                        	                                	my $msg = "\tSucessfully registered VM" . $templateString . ": " . color("magenta") . $vmname . color("reset") . "!";
                                	        	                &getStatus($taskRef,$msg);
								}
                                                	}
                                        	}
                                	}
                        	}
                       		# clear hosts
                        	@hosts = ();
                	}
		}
         }
}

sub verifyDatastore {
	my ($ds) = @_;
	my $dsname = $ds->name;
	my $ret = "yes";
	if($searchSpecificDatastores eq "yes") {
		if (! grep( /^$dsname/,@datastore_search ) ) {
			$ret = "no";	
		}
	}
	return $ret;
}

sub getStatus {
        my ($taskRef,$message) = @_;

        my $task_view = Vim::get_view(mo_ref => $taskRef);
        my $taskinfo = $task_view->info->state->val;
        my $continue = 1;
        while ($continue) {
                my $info = $task_view->info;
                if ($info->state->val eq 'success') {
                        print $message,"\n\n";
                        return $info->result;
                        $continue = 0;
                } elsif ($info->state->val eq 'error') {
                        my $soap_fault = SoapFault->new;
			$soap_fault->name($info->error->fault);
                        $soap_fault->detail($info->error->fault);
                        $soap_fault->fault_string($info->error->localizedMessage);
			if(ref($info->error->fault) eq 'AlreadyExists') {
				print "\tERROR: VM already registered!\n\n";
			} else {
				print "\tERROR: Unable to register VM - " . color("red") . $info->error->localizedMessage . color("reset") . "\n\n";
			}
			$continue = 0;
		}
                sleep 5;
                $task_view->ViewBase::update_view_data();
        }
}
