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
# 08/11/2009
# http://communities.vmware.com/docs/DOC-10497
# http://engineering.ucsb.edu/~duonglt/vmware/

use strict;
use warnings;
use VMware::VIFPLib;
use VMware::VIRuntime;

my %opts = (
   vmname => {
      type => "=s",
      help => "Name of VM to take screen capture",
      required => 1,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $screenshot_dir="vm_screenshots";
my $vm_name = Opts::get_option('vmname');

my $vm_view = Vim::find_entity_view(
                view_type => "VirtualMachine",
                filter => { 'name' => $vm_name },
);

unless (defined $vm_view){
        die "No VM found with name \"$vm_name\".\n";
}

#validate ESX/ESXi host
my $content = Vim::get_service_content();
my $host_type = $content->about->apiType;
my ($host, $host_username,$host_password,$datastore_view,$datastore_name,$conf);

if($host_type eq 'HostAgent') {
       	my $host_view  = Vim::get_view(mo_ref => $vm_view->runtime->host);
	$host = $host_view->name;
	
	my $files = $vm_view->layoutEx->file;
	foreach(@$files) {
		if($_->type eq 'config') {
			($datastore_name,$conf) = split(']',$_->name);
		}
	}	

	$host_username = Opts::get_option('username');
	$host_password = Opts::get_option('password');

	if(!defined($host_username) || !defined($host_password)) {
		print "Error: Unable to retrieve ESX(i) host credentials!\n";
		exit 1
	}

} else {
	print "Error: please execute this against an ESX(i) Server and not vCenter.\n";
	exit 1;
}

eval {
	my ($task_ref,$index,$screenshot_name,$screenshot_path,$screenshot_file);

	# take screenshot
	print "\nInitiating screenshot of " . $vm_name . " ...\n";
	$task_ref = $vm_view->CreateScreenshot_Task();
	my $msg = "Successfully capture screenshot from $vm_name!";
	$screenshot_path = &getStatus($task_ref,$msg);

	$index = rindex($screenshot_path,'/');
	$screenshot_name = substr($screenshot_path,$index+1);
	$screenshot_path =~ s/^\/vmfs\/volumes\/([a-z0-9]*-[a-z0-9]*)*//g;
	$screenshot_file = substr($screenshot_path,1,256);

	# create folder to hold all screen captures
	if( ! -d "$screenshot_dir") {
		mkdir("$screenshot_dir", 0777); 	
	} 

	#download screenshot
	print "Downloading \"$screenshot_name\" to \"$screenshot_dir/$screenshot_name\"\n";

	my $out= `vifs --server "$host" --username "$host_username" --password "$host_password" --get "$datastore_name] $screenshot_file" "$screenshot_dir/$screenshot_name" 2>&1`;

	#delete screenshot
	print "Removing screenshot \"$screenshot_name\" from ESX(i) host ...\n";
	`vifs --server "$host" --username "$host_username" --password "$host_password" --rm "$datastore_name] $screenshot_file" "$screenshot_dir/$screenshot_name" --force 2>&1`;
};

if($@) {
	print "Error: " . $@ . "\n";
}

Util::disconnect();

sub getStatus {
        my ($taskRef,$message) = @_;

        my $task_view = Vim::get_view(mo_ref => $taskRef);
        my $taskinfo = $task_view->info->state->val;
        my $continue = 1;
        while ($continue) {
                my $info = $task_view->info;
                if ($info->state->val eq 'success') {
                        print $message,"\n";
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
