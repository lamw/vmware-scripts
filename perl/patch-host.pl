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

use strict;
use warnings;
use VMware::VIRuntime;
use VMware::Vix::Simple;
use VMware::Vix::API::Constants;

my $psvm_username = "administrator";
my $psvm_password = "mysuperdupersecurepassword";
my $powercli_bin = "C:\\WINDOWS\\system32\\windowspowershell\\v1.0\\powershell.exe";
my $powercli_options = "-psc \"C:\\Program Files\\VMware\\Infrastructure\\vSphere PowerCLI\\vim.psc1\"";

my %opts = (
   'vihost' => {
        type => "=s",
        help => "The name of the ESX(i) host to patch",
        required => 1,
   },
   'psvm' => {
        type => "=s",
        help => "The name of the VM running PowerCLI",
        required => 1,
   },
   'baseline' => {
        type => "=s",
        help => "The name of the VUM baseline to attach and apply",
        required => 1,
   },
);

Opts::add_options(%opts);
# read/validate options and connect to the server
Opts::parse();
Opts::validate();
Util::connect();

my ($host_view, $vm_view, $psvm_path, $task_ref);

my $hosttype = &validateConnection('4.0.0','licensed','VirtualCenter');

my $vihost = Opts::get_option('vihost');
my $baseline = Opts::get_option('baseline');
my $psvm = Opts::get_option('psvm');

$vm_view = Vim::find_entity_view(view_type => 'VirtualMachine', filter => { 'name' => $psvm});

unless($vm_view) {
        Util::disconnect();
        print "Unable to find VM: \"$psvm\"\n";
        exit 1;
}
$psvm_path = $vm_view->config->files->vmPathName;

$host_view = Vim::find_entity_view(view_type => 'HostSystem', filter => { 'name' => $vihost});

unless($host_view) {
        Util::disconnect();
        print "Unable to find Host: \"$vihost\"\n";
        exit 1;
}

if(!$host_view->runtime->inMaintenanceMode) {
        print "Entering maintenance mode for " . $host_view->name . "\n";
        $task_ref = $host_view->EnterMaintenanceMode_Task(timeout => 0, evacuatePoweredOffVms => 1);
        my $msg = "\tSuccessfully entered maintenance mode for " . $host_view->name . "\n";
        &getStatus($task_ref,$msg);
} else {
        print $host_view->name . " is already in maintenance mode\n";
}

my $ret = &doVIXStuff($host_view->name,Opts::get_option('server'),Opts::get_option('username'),Opts::get_option('password'),$psvm_path,$baseline);
if($ret) {
        print "Successfully patched " . $host_view->name . " using VUM baseline: " . $baseline . "\n";
} else {
	print "Failed to patch " . $host_view->name . "\n";
}

Util::disconnect();

sub doVIXStuff {
        my ($host,$vcenter,$vcenter_username,$vcenter_password,$vmpath,$baseline) = @_;

        my $vumps_script_dst = "/tmp/patch-host-$host-$$.ps1";
        my $vumps_script = "patch-host-$host-$$.ps1";
        my $return = 1;

        open(VUMSCRIPT, ">$vumps_script_dst");
        print VUMSCRIPT "Connect-VIServer -Server $vcenter -Protocol https -User $vcenter_username -Password $vcenter_password\n";
        print VUMSCRIPT "\$vmhost = Get-VMHost \"$host\"\n";
        print VUMSCRIPT "\$baseline = Get-Baseline \"$baseline\"\n";
        print VUMSCRIPT "\$baseline | Attach-Baseline -Entity \$vmhost -Confirm:\$false\n";
        print VUMSCRIPT "\$vmhost | Scan-Inventory\n";
        print VUMSCRIPT "\$baseline | Remediate-Inventory -Entity \$vmhost -Confirm:\$false\n";
        close VUMSCRIPT;

        # now start the VIX stuff to run diskpart.exe and extend the partition and the NTTFS volume.
        my ($err,$handle,$vmHandle);

        ($err, $handle) = HostConnect(VIX_API_VERSION,
                                   VIX_SERVICEPROVIDER_VMWARE_VI_SERVER,
                                   "https://" . $vcenter . "/sdk",
                                   0,
                                   $vcenter_username,
                                   $vcenter_password,
                                   0,
                                   VIX_INVALID_HANDLE);

        if ( $err != VIX_OK ) {
                $return = 0;
                Util::disconnect();
                die "Could not connect to vCenter Server: ", GetErrorText($err), "($err)\n" ;
        }
        ($err, $vmHandle) = VMOpen($handle, $vmpath);
        if ( $err != VIX_OK ) {
                $return = 0;
                Util::disconnect();
                die "Could not open $vmpath: ", GetErrorText($err), "($err)\n" ;
        }

        # login to the guest
        $err = VMLoginInGuest($vmHandle,                 # VM handle
                           $psvm_username,               # guest username
                           $psvm_password,               # guest password
                           0);                           # options

        if ( $err != VIX_OK ) {
                Util::disconnect();
                die "Could not open $vmpath: ", GetErrorText($err), "($err)\n" ;
        }
        print "\tGuest login successfully!\n";

        # copy the script to C:\
        $err = VMCopyFileFromHostToGuest($vmHandle,                # VM handle
                                      "$vumps_script_dst",         # source file
                                      "C:\\$vumps_script", # destination file
                                      0,                           # options
                                      VIX_INVALID_HANDLE);         # property list

        if ( $err != VIX_OK ) {
                $return = 0;
                Util::disconnect();
                die "Could not copy $vumps_script_dst to guest: ", GetErrorText($err), "($err)\n" ;
        }

        print "\tCopy $vumps_script to guest successfully!\n";

        # execute
        $err = VMRunProgramInGuest($vmHandle,
                                "$powercli_bin",
                                "$powercli_options C:\\$vumps_script",
                                0,
                                VIX_INVALID_HANDLE);

        if ( $err != VIX_OK ) {
                $return = 0;
                Util::disconnect();
                die "Could not run $vumps_script_dst in guest: ", GetErrorText($err), "($err)\n" ;
        }

        print "\tPowerCLI/VUM script executed successfully!\n";

        # remove file
        $err = VMDeleteFileInGuest($vmHandle,
                                "C:\\$vumps_script");

        if ( $err != VIX_OK ) {
                $return = 0;
                Util::disconnect();
                die "Could not remove $vumps_script_dst in guest: ", GetErrorText($err), "($err)\n" ;
        }

        print "\tScript removed successfully!\n";

        # this may not be needed?
        ReleaseHandle($vmHandle);
        HostDisconnect($handle);

        return $return;
}

sub validateConnection {
        my ($host_version,$host_license,$host_type) = @_;
        my $service_content = Vim::get_service_content();
        my $licMgr = Vim::get_view(mo_ref => $service_content->licenseManager);

        ########################
        # vpx only
        ########################
        if($service_content->about->productLineId ne "vpx") {
                Util::disconnect();
                print "This script will only work on vCenter\n\n";
                exit 1;
        }

        ########################
        # CHECK HOST VERSION
        ########################
        if(!$service_content->about->version ge $host_version) {
                Util::disconnect();
                print "This script requires your ESXi host to be greater than $host_version\n\n";
                exit 1;
        }

        ########################
        # CHECK HOST LICENSE
        ########################
        my $licenses = $licMgr->licenses;
        foreach(@$licenses) {
                if($_->editionKey eq 'esxBasic' && $host_license eq 'licensed') {
                        Util::disconnect();
                        print "This script requires your ESXi be licensed, the free version will not allow you to perform any write operations!\n\n";
                        exit 1;
                }
        }

        ########################
        # CHECK HOST TYPE
        ########################
        if($service_content->about->apiType ne $host_type && $host_type ne 'both') {
                Util::disconnect();
                print "This script needs to be executed against $host_type\n\n";
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
                        print $message;
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
