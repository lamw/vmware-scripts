#!/usr/bin/perl -w
# Author: William Lam
# Website: www.virtuallyghetto.com
# Reference: http://www.virtuallyghetto.com/2014/03/exploring-vsan-apis-part-7-vsan-datastore-folder-management.html

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::VILib;

# define custom options for vm and target host
my %opts = (
   'root-folder' => {
      type => "=s",
      help => "Name of root folder to create",
      required => 1,
   },
   'sub-folder' => {
      type => "=s",
      help => "Name of sub-folder to create",
      required => 1,
   },
   'vsan-datastore' => {
      type => "=s",
      help => "Name of VSAN Datastore",
      required => 1,
   },
);

$SIG{__DIE__} = sub{Util::disconnect()};

# read and validate command-line parameters 
Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $root_folder = Opts::get_option("root-folder");
my $sub_folder = Opts::get_option("sub-folder");
my $vsan_datastore = Opts::get_option("vsan-datastore");

my $datastore_view = Vim::find_entity_view(view_type => 'Datastore', filter => { 'name' => $vsan_datastore}, properties => ['parent','name']);
unless($datastore_view) {
       	Util::disconnect();
       	print "Error: Unable to find VSAN Datastore " . $vsan_datastore . "\n";
       	exit 1;
}

&createRootVSANFolder($datastore_view,$root_folder);

Util::disconnect();

sub createRootVSANFolder {
	my ($datastore,$folder) = @_;

	my $datastoreNameSpaceMgr = Vim::get_view(mo_ref => Vim::get_service_content()->datastoreNamespaceManager);

	eval {
		print "Creating VSAN top-level folder " . $folder . " ...\n";
		my $dir = $datastoreNameSpaceMgr->CreateDirectory(datastore => $datastore, displayName => $folder);
		if($dir) {
			print "Successfully created " . $dir . "\n";
		} else {
			print "Unable to create directory :(\n";
		}
		# create sub folder using fileManager
		&createSubVSANFolder($datastore_view,$folder,$sub_folder);
	};
	if($@) {
		print "Error: " . $@ . "\n";
		Util:disconnect();
		exit 1;
	}
}

sub createSubVSANFolder {
	my ($datastore,$folder,$sub_folder) = @_;

	my $fileMgr = Vim::get_view(mo_ref => Vim::get_service_content()->fileManager);

	eval {
		# Get view to the Datacenter VSAN Datastore belongs to
		my $datacenter = Vim::get_view(mo_ref => Vim::get_view(mo_ref => $datastore->parent)->parent, properties => ['name']);

		# construct folder path
		my $datacenterPath = '[' . $datastore->{'name'} . '] ' . $folder . '/' . $sub_folder;
		print "Creating sub-directory " . $datacenterPath . "\n"; 
		$fileMgr->MakeDirectory(name => $datacenterPath, datacenter => $datacenter);
	};
	if($@) {
		print "Error: " . $@ . "\n";
		Util:disconnect();
		exit 1;
	}
}
