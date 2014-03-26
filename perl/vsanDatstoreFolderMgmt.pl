#!/usr/bin/perl -w
# Copyright (c) 2009-2014 William Lam All rights reserved.

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
# www.virtuallyghetto.com

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
