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
# 08/28/09
# http://communities.vmware.com/docs/DOC-10651
# http://engineering.ucsb.edu/~duonglt/vmware

use strict;
use warnings;
use VMware::VILib;
use VMware::VIFPLib;
use VMware::VIRuntime;
use VMware::VIExt;

my %opts = (
   vihost => {
      type => "=s",
      help => "Name of ESXi host",
      required => 1,
   },
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();

my $vihost = Opts::get_option('vihost');

my ($host_view,$firmwareSystem,$service_content,$host_username,$host_password);

$service_content = Vim::get_service_content();

$host_view = Vim::find_entity_view(view_type => 'HostSystem', filter => { name => $vihost});

unless($host_view) {
        die "Unable to locate ESXi host \"$vihost\"!";
}

eval {
        print "\"$vihost\" is entering maintenance mode ...\n";
        my $task_ref = $host_view->EnterMaintenanceMode_Task(timeout => 0, evacuatePoweredOffVms => 1);
        my $msg = "\t\"$vihost\" has successfully entered maintenance mode!";
        &getStatus($task_ref,$msg);
};
if($@) {
        die "Error: " . $@ . "\n";
}

# if ESXi host is attached to vCenter, we'll want to remove
if($service_content->about->apiType eq 'VirtualCenter') {
        eval {
                print "Removing \"$vihost\" from vCenter ...\n";
                my $task_ref = $host_view->Destroy_Task();
                my $msg = "\t\"$vihost\" has successfully been remove from vCenter!";
                &getStatus($task_ref,$msg);
        };
        if($@) {
                die "Error: " . $@ . "\n";
        }

        #requires vMA + ESXi host being managed by vMA
        my $viuser = vifplib_perl::CreateVIUserInfo();
        my $vifplib = vifplib_perl::CreateVIFPLib();
        eval { $vifplib->QueryTarget($vihost, $viuser); };
        if(!$@) {
                $host_username = $viuser->GetUsername();
                $host_password = $viuser->GetPassword();
        } else {
                print "Error: It does not seem like you're managing this ESXi host with vMA!.\n";
                exit 1;
        }

        Util::disconnect();

        my $url = "https://$vihost/sdk";
        Util::connect($url,$host_username,$host_password);

        $host_view = Vim::find_entity_view(view_type => 'HostSystem', filter => { name => $vihost});

}

$firmwareSystem = Vim::get_view(mo_ref => $host_view->configManager->firmwareSystem);

eval {
        print "Resetting factory settings on \"$vihost\"!\n";
        $firmwareSystem->ResetFirmwareToFactoryDefaults();
};
if($@) {
        die "Error: " . $@ . "\n";
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
